#!/bin/bash
# Server-Backup  Copyright (C) 2012
#                Antonio Espinosa <aespinosa at teachnova dot com>
#
# This file is part of Server-Backup by Teachnova (www.teachnova.com)
#
# Server-Backup is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Server-Backup is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Server-Backup.  If not, see <http://www.gnu.org/licenses/>.

##################################################################
# Get time
BAK_START_DATE=`date`
BAK_TIMESTAMP=`date +%s`
BAK_DATE=`date +%F_%T | tr -d ':'`

##################################################################
# BACKUP paths
root_path() {
   SOURCE="${BASH_SOURCE[0]}"
   DIR="$( dirname "$SOURCE" )"
   while [ -h "$SOURCE" ]
   do
     SOURCE="$( readlink "$SOURCE" )"
     [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
     DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
   done
   DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

   echo "$DIR"
}

BAK_PATH=`root_path`

BAK_LOG_DIR=log
BAK_CONFIG_DIR=config
BAK_CONFIG_DIST_DIR=config-dist
BAK_LIB_DIR=lib

BAK_LOG_PATH="$BAK_PATH/$BAK_LOG_DIR"
BAK_CONFIG_PATH="$BAK_PATH/$BAK_CONFIG_DIR"
BAK_CONFIG_DIST_PATH="$BAK_PATH/$BAK_CONFIG_DIST_DIR"
BAK_LIB_PATH="$BAK_PATH/$BAK_LIB_DIR"

if [ ! -d "$BAK_CONFIG_PATH" ] && [ -d "$BAK_CONFIG_DIST_PATH" ]; then
   echo "INFO : Config directory not found"
   echo "INFO : Creating config directory from '$BAK_CONFIG_DIST_DIR'"
   /bin/cp -a "$BAK_CONFIG_DIST_PATH" "$BAK_CONFIG_PATH"
fi

### Default Configuration ##################################################

BAK_ENABLED=0
BAK_DEBUG=1

BAK_SEND_MAIL_ERR=0
BAK_SEND_MAIL_LOG=0

BAK_ENCRYPT=1

BAK_MYSQL_DATABASE_ENABLED=1
BAK_MYSQL_DATABASE_WARNING_IF_DOWN=0
BAK_MYSQL_DATABASE_ALLOW_ALL=1

BAK_POSTGRESQL_DATABASE_ENABLED=1
BAK_POSTGRESQL_DATABASE_WARNING_IF_DOWN=0
BAK_POSTGRESQL_DATABASE_ALLOW_ALL=1

### Configuration ##################################################

BAK_CONFIG_GENERAL_FILE="$BAK_CONFIG_PATH/general.conf"
if [ -f "$BAK_CONFIG_GENERAL_FILE" ]; then
   . "$BAK_CONFIG_GENERAL_FILE"
else
   echo "ERROR : No general configuration file found '$BAK_CONFIG_GENERAL_FILE'" 2>&1
   exit 1
fi

# Load server configuration config file
BAK_CONFIG_SERVER_FILE="$BAK_CONFIG_PATH/config.conf"
if [ -f "$BAK_CONFIG_SERVER_FILE" ]; then
   . "$BAK_CONFIG_SERVER_FILE"
else
   echo "ERROR : No server configuration file found '$BAK_CONFIG_SERVER_FILE'" 2>&1
   exit 1
fi

# Load databases config file
BAK_CONFIG_DATABASE_FILE="$BAK_CONFIG_PATH/database.conf"
if [ -f "$BAK_CONFIG_DATABASE_FILE" ]; then
   . "$BAK_CONFIG_DATABASE_FILE"
else
   echo "ERROR : No database configuration file found '$BAK_CONFIG_DATABASE_FILE'" 2>&1
   exit 1
fi

# Load main library
BAK_LIB_MAIN_FILE="$BAK_LIB_PATH/main.sh"
if [ -f "$BAK_LIB_MAIN_FILE" ]; then
   . "$BAK_LIB_MAIN_FILE"
else
   echo "ERROR : No main lib file found '$BAK_LIB_MAIN_FILE'" 2>&1
   exit 1
fi


### Global variables #############################################

# Sources configuration
BAK_SOURCES_CONFIG_SOURCE=
BAK_SOURCES_CONFIG_TARGET=
BAK_SOURCES_CONFIG_ARGS=
BAK_SOURCES_CONFIG_TYPE=
BAK_SOURCES_CONFIG_INC=

backup_error=0

### Auxiliar functions #############################################

# Load backends configuration files
for backend in $BAK_BACKENDS; do
   backend_file="$BAK_CONFIG_PATH/$backend.conf"
   if [ -f "$backend_file" ]; then
      . "$backend_file"
   else
      echo "ERROR : No backend ($backend) configuration file found '$backend_file'" 2>&1
      exit 1
   fi
done

### MAIN #############################################

# If any option ...

if [ -n "$1" ]; then
   case "$1" in
      -v | --version )
         version_show
         exit 0
         ;;

      -h | --help )
         help_show
         exit 0
         ;;

      -c | --config )
         config_show
         exit 0
         ;;

      -s | --snapshot )
         snapshot
         exit $?
         ;;

      -r | --restore )
         restore
         exit $?
         ;;

      -l | --list )
         list
         exit $?
         ;;

      *)
         $ECHO_BIN "ERROR : Option not supported" 2>&1
         $ECHO_BIN 2>&1
         help_show
         exit 1
         ;;
   esac
fi

# No option set, execute backup

# Setup (if needed)
executable_set "$BAK_PATH/backup.sh"

$CHMOD_BIN 640 "$BAK_CONFIG_PATH/enc.key"
$CHOWN_BIN root:root "$BAK_CONFIG_PATH/enc.key"

# Check environment
environment_check

if [ $BAK_ENABLED -eq 0 ]; then
   config_show
   $ECHO_BIN "INFO : Backup is disabled by config. Please modify configuration in order to perform a backup"
   $ECHO_BIN "INFO : Read README.md file to further information about Configuration"
   exit 1
fi

# Check log directory and create it (if needed)
log_directory_create

# Start log
log_start_print "BACKUP"

# Check lock
if ! lock_check_and_set; then
   log_end_print "BACKUP"
   mail_error_send
   exit 1
fi

# Mount devices (if any)
if ! mount_devices; then
   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "ERROR: Reading mounting devices" >> $BAK_OUTPUT
   log_end_print "BACKUP"
   mail_error_send
   exit 1
fi

# Check directories and create them (if needed)
directories_create

# Load sources configuration
if ! source_config_read "$BAK_SOURCES_CONFIG_FILE"; then
   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "ERROR: Reading configuration (config file = $BAK_SOURCES_CONFIG_FILE)" >> $BAK_OUTPUT
   log_end_print "BACKUP"
   mail_error_send
   exit 1
fi

# Delete local backend (if enabled)
if [ -n "$BAK_LOCAL_PATH" ]; then
   $ECHO_BIN -n "Deleting local backend ... " >> $BAK_OUTPUT
   $ECHO_BIN " CMD : $RM_BIN '$BAK_LOCAL_PATH/*'" >> $BAK_OUTPUT_EXTENDED
   $RM_BIN "$BAK_LOCAL_PATH"/*
   $ECHO_BIN "OK" >> $BAK_OUTPUT
fi

# Delete tmp directory
$ECHO_BIN -n "Deleting tmp directory ... " >> $BAK_OUTPUT
$ECHO_BIN " CMD : $RM_BIN '$BAK_TEMP_PATH/*'" >> $BAK_OUTPUT_EXTENDED
$RM_BIN "$BAK_TEMP_PATH"/*
$ECHO_BIN "OK" >> $BAK_OUTPUT

# Delete out directory
$ECHO_BIN -n "Deleting out directory ... " >> $BAK_OUTPUT
$ECHO_BIN " CMD : $RM_BIN '$BAK_OUTPUT_PATH/*'" >> $BAK_OUTPUT_EXTENDED
$RM_BIN "$BAK_OUTPUT_PATH"/*
$ECHO_BIN "OK" >> $BAK_OUTPUT

# Backup configuration
server_configuration_backup
berror=$?
if [ $berror -ne 0 ]; then $ECHO_BIN "ERROR : Making Server Configuration backup (error = $berror)" >> $BAK_OUTPUT; fi
if [ $backup_error -eq 0 ]; then backup_error=$berror; fi

# Backup MySQL databases
mysql_databases_backup
berror=$?
if [ $berror -ne 0 ]; then $ECHO_BIN "ERROR : Making MySQL Databases backup (error = $berror)" >> $BAK_OUTPUT; fi
if [ $backup_error -eq 0 ]; then backup_error=$berror; fi

# Backup PostgreSQL databases
postgresql_databases_backup
berror=$?
if [ $berror -ne 0 ]; then $ECHO_BIN "ERROR : Making PostgreSQL Databases backup (error = $berror)" >> $BAK_OUTPUT; fi
if [ $backup_error -eq 0 ]; then backup_error=$berror; fi

# Backup sources
sources_backup_loop
berror=$?
if [ $berror -ne 0 ]; then $ECHO_BIN "ERROR : Making Sources backup (error = $berror)" >> $BAK_OUTPUT; fi
if [ $backup_error -eq 0 ]; then backup_error=$berror; fi

info_get

old_files_rm $BAK_LOG_PATH $BAK_RM_LOG_OLDER_THAN_DAY

# UnMount devices (if any)
umount_devices

# End log
log_end_print "BACKUP"

# TODO : Copy report to backends

# Send report email
if [ $backup_error -eq 0 ]; then
   mail_log_send
else
   mail_error_send
fi

exit 0
















