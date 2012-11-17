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
BAK_LIB_DIR=lib

BAK_LOG_PATH="$BAK_PATH/$BAK_LOG_DIR"
BAK_CONFIG_PATH="$BAK_PATH/$BAK_CONFIG_DIR"
BAK_LIB_PATH="$BAK_PATH/$BAK_LIB_DIR"


### Configuration ##################################################

BAK_CONFIG_GENERAL_FILE="$BAK_CONFIG_PATH/general.conf"
if [ -f "$BAK_CONFIG_GENERAL_FILE" ]; then
   . "$BAK_CONFIG_GENERAL_FILE"
else
   echo "ERROR : No general configuration file found '$BAK_CONFIG_GENERAL_FILE'"
   exit 1
fi

# Load server configuration config file
BAK_CONFIG_SERVER_FILE="$BAK_CONFIG_PATH/config.conf"
if [ -f "$BAK_CONFIG_SERVER_FILE" ]; then
   . "$BAK_CONFIG_SERVER_FILE"
else
   echo "ERROR : No server configuration file found '$BAK_CONFIG_SERVER_FILE'"
   exit 1
fi

# Load databases config file
BAK_CONFIG_DATABASE_FILE="$BAK_CONFIG_PATH/database.conf"
if [ -f "$BAK_CONFIG_DATABASE_FILE" ]; then
   . "$BAK_CONFIG_DATABASE_FILE"
else
   echo "ERROR : No database configuration file found '$BAK_CONFIG_DATABASE_FILE'"
   exit 1
fi

# Load backends configuration files
for backend in $BAK_BACKENDS; do
   backend_file="$BAK_CONFIG_PATH/$backend.conf"
   if [ -f "$backend_file" ]; then
      . "$backend_file"
   else
      echo "ERROR : No backend ($backend) configuration file found '$backend_file'"
      exit 1
   fi
done

### Global variables #############################################

# Sources configuration
BAK_SOURCES_CONFIG_SOURCE=
BAK_SOURCES_CONFIG_TARGET=
BAK_SOURCES_CONFIG_ARGS=
BAK_SOURCES_CONFIG_TYPE=
BAK_SOURCES_CONFIG_INC=

backup_error=0

### Auxiliar functions #############################################

BAK_LIB_MAIN_FILE="$BAK_LIB_PATH/main.sh"

if [ -f "$BAK_LIB_MAIN_FILE" ]; then
   . "$BAK_LIB_MAIN_FILE"
else
   echo "ERROR : No main lib file found '$BAK_LIB_MAIN_FILE'"
   exit 1
fi

### MAIN #############################################

# Check environment
environment_check

# Check directories and create if needed
directories_create

# Start log
log_start_print

# Mount devices (if any)
   ############################################
   # TODO : Mount devices for usb backend #####
   ############################################

# Load sources configuration
if ! source_config_read "$BAK_SOURCES_CONFIG_FILE"; then
   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "ERROR: Reading configuration (config file = $BAK_SOURCES_CONFIG_FILE)" >> $BAK_OUTPUT
   mail_error_send
   exit 1
fi

# Delete local backend (if enabled)
if [ -n "$BAK_LOCAL_PATH" ]; then
   $ECHO_BIN -n "Deleting local backend ... " >> $BAK_OUTPUT
   $RM_BIN "$BAK_LOCAL_PATH"/*
   $ECHO_BIN "OK" >> $BAK_OUTPUT
fi

# Backup configuration
if [ $backup_error -eq 0 ]; then
   server_configuration_backup
   backup_error=$?
fi

# Backup databases
if [ $backup_error -eq 0 ]; then
   mysql_databases_backup
   backup_error=$?
fi

# Backup sources
if [ $backup_error -eq 0 ]; then
   sources_backup_loop
   backup_error=$?
fi

info_get

old_files_rm $BAK_LOG_PATH $BAK_RM_LOG_OLDER_THAN_DAY

# End log
log_end_print

# Copy report to backends

# Send report email
if [ $backup_error -eq 0 ]; then
   mail_log_send
else
   mail_error_send
fi

exit 0
















