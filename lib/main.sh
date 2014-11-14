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
# BACKUP Constants

BAK_VERSION=1.0

BAK_TEMP_DIR=tmp
BAK_OUTPUT_DIR=out
BAK_HISTORICAL_DIR=historical

BAK_TEMP_PATH=$BAK_DATA_PATH/$BAK_TEMP_DIR
BAK_OUTPUT_PATH=$BAK_DATA_PATH/$BAK_OUTPUT_DIR
BAK_HISTORICAL_PATH=$BAK_DATA_PATH/$BAK_HISTORICAL_DIR

BAK_BACKEND_MAX_RETRIES=3

##################################################################
# BACKUP Output

BAK_OUTPUT=$BAK_PATH/$BAK_LOG_DIR/bak_log_${BAK_DATE}_$$.txt
BAK_OUTPUT_EXTENDED=$BAK_PATH/$BAK_LOG_DIR/bak_log_${BAK_DATE}_$$_ext.txt
# BAK_OUTPUT=/dev/stdout
BAK_NULL_OUTPUT=/dev/null

##################################################################
# BACKUP Lock
BAK_LOCK=/var/lock/server_backup.lock

##################################################################
# BACKUP Data sources

BAK_SOURCES_CONFIG_FILE=$BAK_PATH/$BAK_CONFIG_DIR/sources.conf

##################################################################
# BACKUP Email

if [ -z "$BAK_MAIL_FROM_USER" ]; then
   user=`whoami`
   domain=`cat /etc/mailname`
   BAK_MAIL_FROM_USER="${user}@${domain}"
fi
if [ -z "$BAK_MAIL_COSTUMER" ]; then
   BAK_MAIL_COSTUMER=`hostname`
fi

BAK_MAIL_FROM="$BAK_MAIL_COSTUMER - Server-Backup <$BAK_MAIL_FROM_USER>"
BAK_MAIL_SUBJECT_ERR="[BACKUP] ERROR - $BAK_MAIL_COSTUMER"
BAK_MAIL_SUBJECT_LOG="[BACKUP] LOG   - $BAK_MAIL_COSTUMER"
BAK_MAIL_TEMP_FILE=/tmp/$$_server_backup_last_email.eml
BAK_MAIL_LAST_FILE=$BAK_PATH/last_email.eml

##################################################################
# BACKUP Backends

BAK_BACKENDS="$BAK_REMOTE_BACKENDS $BAK_LOCAL_BACKENDS"

##################################################################
# BACKUP external commands

TAR_FILE=/bin/tar
TAR_BIN="$TAR_FILE"
TAR_OPTS="-cvjf"
COMPRESS_BIN="$TAR_FILE -czf"

RM_FILE=/bin/rm
RM_BIN="$RM_FILE -rf"

MV_FILE=/bin/mv
MV_BIN="$MV_FILE"

CP_FILE=/bin/cp
CP_BIN="$CP_FILE -a"

MKDIR_FILE=/bin/mkdir
MKDIR_BIN="$MKDIR_FILE -p"

CAT_FILE=/bin/cat
CAT_BIN="$CAT_FILE"

FIND_FILE=/usr/bin/find
FIND_BIN="$FIND_FILE"

GREP_FILE=/bin/grep
GREP_BIN="$GREP_FILE"

SU_FILE=/bin/su
SU_BIN="$SU_FILE -"

DF_FILE=/bin/df
DF_BIN="$DF_FILE -h"

LS_FILE=/bin/ls
FILE_SIZE_BIN="$LS_FILE -s -h"

DU_FILE=/usr/bin/du
DIR_SIZE_BIN="$DU_FILE -s -h"

SENDMAIL_FILE=/usr/sbin/sendmail
SENDMAIL_BIN="$SENDMAIL_FILE"

OPENSSL_FILE=/usr/bin/openssl
OPENSSL_ENC_BIN="$OPENSSL_FILE enc $BAK_ENCRYPT_ALG -salt -pass file:$BAK_ENCRYPT_KEY_FILE"

ECHO_FILE=/bin/echo
ECHO_BIN="$ECHO_FILE"

CUT_FILE=/usr/bin/cut
CUT_BIN="$CUT_FILE"

DATE_FILE=/bin/date
DATE_BIN="$DATE_FILE"

CHMOD_FILE=/bin/chmod
CHMOD_BIN="$CHMOD_FILE"

CHOWN_FILE=/bin/chown
CHOWN_BIN="$CHOWN_FILE"

KILL_FILE=/bin/kill
PID_CHECK_BIN="$KILL_FILE -0"

SED_FILE=/bin/sed
SED_BIN="$SED_FILE -e"

MD5SUM_FILE=/usr/bin/md5sum
MD5SUM_BIN="$MD5SUM_FILE"

SERVICE_FILE=/usr/sbin/service
SERVICE_BIN="$SERVICE_FILE"

MOUNT_FILE=/bin/mount
MOUNT_BIN="$MOUNT_FILE"

UMOUNT_FILE=/bin/umount
UMOUNT_BIN="$UMOUNT_FILE"

MOUNT_NFS_FILE=/sbin/mount.nfs
MOUNT_NFS_BIN="$MOUNT_NFS_FILE"

UMOUNT_NFS_FILE=/sbin/umount.nfs
UMOUNT_NFS_BIN="$UMOUNT_NFS_FILE"

BAK_ENVIRONMENT_LIST=(
   "$TAR_FILE"
   "$RM_FILE"
   "$MV_FILE"
   "$CP_FILE"
   "$MKDIR_FILE"
   "$CAT_FILE"
   "$FIND_FILE"
   "$GREP_FILE"
   "$SU_FILE"
   "$DF_FILE"
   "$LS_FILE"
   "$DU_FILE"
   "$SENDMAIL_FILE"
   "$OPENSSL_FILE"
   "$ECHO_FILE"
   "$CUT_FILE"
   "$CHMOD_FILE"
   "$CHOWN_FILE"
   "$KILL_FILE"
   "$SED_FILE"
   "$MD5SUM_FILE"
   "$SERVICE_FILE"
   "$MOUNT_FILE"
   "$UMOUNT_FILE"
)

##################################################################
# BACKUP Library functions

is_function() {
   if echo `type $1 2> /dev/null` | $GREP_BIN -q "is a function"; then
      return 0
   else
      return 1
   fi
}

##################################################################
# old_files_rm
#  Remove old files recursive
##################################################################
old_files_rm () {
   local PATH=$1
   local DAYS=$2
   local file=

   if [ -n "$PATH" ] && [ -n "$DAYS" ]; then
      $ECHO_BIN "Deleting files from '$PATH' older than $DAYS days" >> $BAK_OUTPUT
      $FIND_BIN "$PATH" -type f -mtime +$DAYS | while read file
      do
         $ECHO_BIN " CMD : $RM_BIN '$file'" >> $BAK_OUTPUT_EXTENDED
         $RM_BIN "$file" >> $BAK_OUTPUT_EXTENDED 2>&1
      done
   else
      $ECHO_BIN "ERROR : Bad parameters in 'old_files_rm' PATH = '$PATH', DAYS = '$DAYS'" >> $BAK_OUTPUT
   fi
}

mysql_check() {
   $ECHO_BIN -n "MySQL status: " >> $BAK_OUTPUT
   $ECHO_BIN "- MYSQL Status --------------------------------" >> $BAK_OUTPUT_EXTENDED
   $SERVICE_BIN mysql status >> $BAK_OUTPUT_EXTENDED 2>&1
   error=$?
   $ECHO_BIN "-----------------------------------------------" >> $BAK_OUTPUT_EXTENDED
   if [ $error -eq 0 ]; then
      $ECHO_BIN -n "OK" >> $BAK_OUTPUT
   else
      $ECHO_BIN -n "FAIL" >> $BAK_OUTPUT
   fi
   $ECHO_BIN " ($error)" >> $BAK_OUTPUT
   return $error
}

##################################################################
# mysql_databases_backup
#  Backup MySQL databases
##################################################################
mysql_databases_backup() {
   local error=0
   local db_error=0
   local size=0
   local file=

   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "Backup MySQL Databases" >> $BAK_OUTPUT

   if [ $BAK_MYSQL_DATABASE_ENABLED -eq 0 ]; then
      $ECHO_BIN "   Disabled by configuration" >> $BAK_OUTPUT
      return 0
   fi

   if [ $BAK_MYSQL_DATABASE_ENABLED -eq 2 ]; then
      $ECHO_BIN "   Disabled because no mysql or mysqldump binaries found" >> $BAK_OUTPUT
      return 0
   fi

   if ! mysql_check; then
      # If make backup of MySQL data folder
      if [ -n "$BAK_MYSQL_DATABASE_DATA_IF_DOWN" ] && [ -d "$BAK_MYSQL_DATABASE_DATA_IF_DOWN" ]; then
         $ECHO_BIN "   WARNING - MySQL is not running, backup of MySQL files" >> $BAK_OUTPUT
         mysql_datafiles_backup "$BAK_MYSQL_DATABASE_DATA_IF_DOWN"
         return $?
      fi

      # If show only a warning
      if [ $BAK_MYSQL_DATABASE_WARNING_IF_DOWN -eq 1 ]; then
         $ECHO_BIN "   WARNING - MySQL is not running, showing warning only" >> $BAK_OUTPUT
         return 0
      fi

      # Else, this is a error to be reported
      $ECHO_BIN "   FAIL - MySQL is not running" >> $BAK_OUTPUT
      return 1
   fi

   for i in $(eval $BAK_MYSQL_DATABASE_LIST_CMD);
   do
      if $(contains "${BAK_MYSQL_DATABASE_DISALLOW[@]}" "$i"); then
         continue
      fi

      $ECHO_BIN -n "   $i ... " >> $BAK_OUTPUT

      if [ $BAK_MYSQL_DATABASE_ALLOW_ALL -eq 1 ] || $(contains "${BAK_MYSQL_DATABASE_ALLOW[@]}" "$i"); then
         file="$BAK_MYSQL_DATABASE_PATH/${BAK_DATE}-${i}.sql"
         if [ $BAK_DEBUG -eq 1 ]; then
            $ECHO_BIN -n "$BAK_MYSQL_DATABASE_BACKUP_CMD $i > '$file' ... " >> $BAK_OUTPUT
         else
            $ECHO_BIN " CMD : $BAK_MYSQL_DATABASE_BACKUP_CMD $i > '$file'" >> $BAK_OUTPUT_EXTENDED
            $BAK_MYSQL_DATABASE_BACKUP_CMD $i > "$file" 2>> $BAK_OUTPUT_EXTENDED
         fi
         db_error=$?
         if [ $db_error -eq 0 ];then
            $ECHO_BIN -n "OK" >> $BAK_OUTPUT
            $ECHO_BIN " CMD : file_size '$file'" >> $BAK_OUTPUT_EXTENDED
            size=`file_size $file`
            $ECHO_BIN " ($size)" >> $BAK_OUTPUT
            $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
         else
            $ECHO_BIN "FAIL (error = $db_error)" >> $BAK_OUTPUT
            error=1
         fi
      else
         $ECHO_BIN "SKIPPED" >> $BAK_OUTPUT
      fi
   done

   # Process this backup
   if [ $error -eq 0 ]; then
      backup_process "$BAK_MYSQL_DATABASE_PATH" "${BAK_DATE}-database"
   fi

   return $error
}

##################################################################
# mysql_datafiles_backup "folder"
#  Backup MySQL data files
##################################################################
mysql_datafiles_backup() {
   local error=0
   local config_error=0
   local name=
   local index=
   local source="$1"
   local file=
   local size=0

   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "Backup MySQL data files" >> $BAK_OUTPUT
   name=${source/\//}
   name=${source//\//_}
   $ECHO_BIN -n "   '$source' ... " >> $BAK_OUTPUT
   if [ -e $source ]; then
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
      current_date=`$DATE_BIN`
      $ECHO_BIN " START $current_date" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " ACTION MySQL data files : $source " >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " CMD : '$TAR_BIN' : source='$source'" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
      file="$BAK_CONFIG_SERVER_PATH/${BAK_DATE}-${name}-backup.tar.bz2"
      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$TAR_BIN $TAR_OPTS '$file' '$source' ... " >> $BAK_OUTPUT
      else
         $ECHO_BIN " CMD : $TAR_BIN $TAR_OPTS '$file' '$source'" >> $BAK_OUTPUT_EXTENDED
         $TAR_BIN $TAR_OPTS "$file" "$source" >> $BAK_OUTPUT_EXTENDED 2>&1
      fi
      config_error=$?
      if [ $config_error -eq 0 ];then
         $ECHO_BIN -n "OK" >> $BAK_OUTPUT
         $ECHO_BIN " CMD : file_size '$file'" >> $BAK_OUTPUT_EXTENDED
         size=`file_size $file`
         $ECHO_BIN " ($size)" >> $BAK_OUTPUT
         $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
      else
         $ECHO_BIN "FAIL (error = $config_error)" >> $BAK_OUTPUT
         error=1
      fi
   else
      $ECHO_BIN "NOT FOUND" >> $BAK_OUTPUT
   fi

   # Process this backup
   if [ $error -eq 0 ]; then
      backup_process "$BAK_CONFIG_SERVER_PATH" "${BAK_DATE}-mysqlfiles"
   fi

   return $error
}

postgresql_check() {
   $ECHO_BIN -n "PostgreSQL status: " >> $BAK_OUTPUT
   $ECHO_BIN "- PostgreSQL Status --------------------------------" >> $BAK_OUTPUT_EXTENDED
   if $POSTGRESQL_LSCLUSTER_BIN | $GREP_BIN 'online' >> $BAK_OUTPUT_EXTENDED 2>&1; then
      error=0
      $ECHO_BIN -n "OK" >> $BAK_OUTPUT
   else
      error=1
      $ECHO_BIN -n "FAIL" >> $BAK_OUTPUT
   fi
   $ECHO_BIN "-----------------------------------------------" >> $BAK_OUTPUT_EXTENDED
   $ECHO_BIN " ($error)" >> $BAK_OUTPUT
   return $error
}

##################################################################
# postgresql_databases_backup
#  Backup PostgreSQL databases
##################################################################
postgresql_databases_backup() {
   local error=0
   local db_error=0
   local size=0
   local file=

   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "Backup PostgreSQL Databases" >> $BAK_OUTPUT

   if [ $BAK_POSTGRESQL_DATABASE_ENABLED -eq 0 ]; then
      $ECHO_BIN "   Disabled by configuration" >> $BAK_OUTPUT
      return 0
   fi

   if [ $BAK_POSTGRESQL_DATABASE_ENABLED -eq 2 ]; then
      $ECHO_BIN "   Disabled because no psql or pgdump or pg_lscluster binaries found" >> $BAK_OUTPUT
      return 0
   fi

   if ! postgresql_check; then
      # If make backup of PostgreSQL data folder
      if [ -n "$BAK_POSTGRESQL_DATABASE_DATA_IF_DOWN" ] && [ -d "$BAK_POSTGRESQL_DATABASE_DATA_IF_DOWN" ]; then
         $ECHO_BIN "   WARNING - PostgreSQL is not running, backup of PostgreSQL files" >> $BAK_OUTPUT
         postgresql_datafiles_backup "$BAK_POSTGRESQL_DATABASE_DATA_IF_DOWN"
         return $?
      fi

      # If show only a warning
      if [ $BAK_POSTGRESQL_DATABASE_WARNING_IF_DOWN -eq 1 ]; then
         $ECHO_BIN "   WARNING - PostgreSQL is not running, showing warning only" >> $BAK_OUTPUT
         return 0
      fi

      # Else, this is a error to be reported
      $ECHO_BIN "   FAIL - PostgreSQL is not running" >> $BAK_OUTPUT
      return 1
   fi

   for i in $(eval $BAK_POSTGRESQL_DATABASE_LIST_CMD);
   do
      if $(contains "${BAK_POSTGRESQL_DATABASE_DISALLOW[@]}" "$i"); then
         continue
      fi

      $ECHO_BIN -n "   $i ... " >> $BAK_OUTPUT

      if [ $BAK_POSTGRESQL_DATABASE_ALLOW_ALL -eq 1 ] || $(contains "${BAK_POSTGRESQL_DATABASE_ALLOW[@]}" "$i"); then
         file="$BAK_POSTGRESQL_DATABASE_PATH/${BAK_DATE}-${i}.sql"
         if [ $BAK_DEBUG -eq 1 ]; then
            $ECHO_BIN -n "$BAK_POSTGRESQL_DATABASE_BACKUP_CMD $i > '$file' ... " >> $BAK_OUTPUT
         else
            $ECHO_BIN " CMD : $BAK_POSTGRESQL_DATABASE_BACKUP_CMD $i > '$file'" >> $BAK_OUTPUT_EXTENDED
            $BAK_POSTGRESQL_DATABASE_BACKUP_CMD $i > "$file" 2>> $BAK_OUTPUT_EXTENDED
         fi
         db_error=$?
         if [ $db_error -eq 0 ];then
            $ECHO_BIN -n "OK" >> $BAK_OUTPUT
            $ECHO_BIN " CMD : file_size '$file'" >> $BAK_OUTPUT_EXTENDED
            size=`file_size $file`
            $ECHO_BIN " ($size)" >> $BAK_OUTPUT
            $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
         else
            $ECHO_BIN "FAIL (error = $db_error)" >> $BAK_OUTPUT
            error=1
         fi
      else
         $ECHO_BIN "SKIPPED" >> $BAK_OUTPUT
      fi
   done

   # Process this backup
   if [ $error -eq 0 ]; then
      backup_process "$BAK_POSTGRESQL_DATABASE_PATH" "${BAK_DATE}-database"
   fi

   return $error
}

##################################################################
# postgresql_datafiles_backup "folder"
#  Backup PostgreSQL data files
##################################################################
postgresql_datafiles_backup() {
   local error=0
   local config_error=0
   local name=
   local index=
   local source="$1"
   local file=
   local size=0

   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "Backup PostgreSQL data files" >> $BAK_OUTPUT
   name=${source/\//}
   name=${source//\//_}
   $ECHO_BIN -n "   '$source' ... " >> $BAK_OUTPUT
   if [ -e $source ]; then
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
      current_date=`$DATE_BIN`
      $ECHO_BIN " START $current_date" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " ACTION PostgreSQL data files : $source " >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " CMD : '$TAR_BIN' : source='$source'" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
      file="$BAK_CONFIG_SERVER_PATH/${BAK_DATE}-${name}-backup.tar.bz2"
      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$TAR_BIN $TAR_OPTS '$file' '$source' ... " >> $BAK_OUTPUT
      else
         $ECHO_BIN " CMD : $TAR_BIN $TAR_OPTS '$file' '$source'" >> $BAK_OUTPUT_EXTENDED
         $TAR_BIN $TAR_OPTS "$file" "$source" >> $BAK_OUTPUT_EXTENDED 2>&1
      fi
      config_error=$?
      if [ $config_error -eq 0 ];then
         $ECHO_BIN -n "OK" >> $BAK_OUTPUT
         $ECHO_BIN " CMD : file_size '$file'" >> $BAK_OUTPUT_EXTENDED
         size=`file_size $file`
         $ECHO_BIN " ($size)" >> $BAK_OUTPUT
         $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
      else
         $ECHO_BIN "FAIL (error = $config_error)" >> $BAK_OUTPUT
         error=1
      fi
   else
      $ECHO_BIN "NOT FOUND" >> $BAK_OUTPUT
   fi

   # Process this backup
   if [ $error -eq 0 ]; then
      backup_process "$BAK_CONFIG_SERVER_PATH" "${BAK_DATE}-mysqlfiles"
   fi

   return $error
}

##################################################################
# server_configuration_backup
#  Backup server configuration files
##################################################################
server_configuration_backup() {
   local error=0
   local config_error=0
   local name=
   local index=
   local source=
   local file=
   local size=0

   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "Backup Server configuration" >> $BAK_OUTPUT
   for index in `seq 0 1 $((${#BAK_CONFIG_SERVER_SOURCES[@]} - 1))`; do
      source="${BAK_CONFIG_SERVER_SOURCES[$index]}"
      name=${source/\//}
      name=${source//\//_}
      $ECHO_BIN -n "   '$source' ... " >> $BAK_OUTPUT
      if [ -e $source ]; then
         $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
         current_date=`$DATE_BIN`
         $ECHO_BIN " START $current_date" >> $BAK_OUTPUT_EXTENDED
         $ECHO_BIN " ACTION Server configuration ($index) : $source " >> $BAK_OUTPUT_EXTENDED
         $ECHO_BIN " CMD : '$TAR_BIN' : source=$source" >> $BAK_OUTPUT_EXTENDED
         $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
         file="$BAK_CONFIG_SERVER_PATH/${BAK_DATE}-${name}-backup.tar.bz2"
         if [ $BAK_DEBUG -eq 1 ]; then
            $ECHO_BIN -n "$TAR_BIN $TAR_OPTS '$file' '$source' ... " >> $BAK_OUTPUT
         else
            $ECHO_BIN " CMD : $TAR_BIN $TAR_OPTS '$file' '$source'" >> $BAK_OUTPUT_EXTENDED
            $TAR_BIN $TAR_OPTS "$file" "$source" >> $BAK_OUTPUT_EXTENDED 2>&1
         fi
         config_error=$?
         if [ $config_error -eq 0 ];then
            $ECHO_BIN -n "OK" >> $BAK_OUTPUT
            $ECHO_BIN " CMD : file_size '$file'" >> $BAK_OUTPUT_EXTENDED
            size=`file_size $file`
            $ECHO_BIN " ($size)" >> $BAK_OUTPUT
            $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
         else
            $ECHO_BIN "FAIL (error = $config_error)" >> $BAK_OUTPUT
            error=1
         fi
     else
        $ECHO_BIN "NOT FOUND" >> $BAK_OUTPUT
     fi
   done

   # Process this backup
   if [ $error -eq 0 ]; then
      backup_process "$BAK_CONFIG_SERVER_PATH" "${BAK_DATE}-serverconfig"
   fi

   return $error
}


##################################################################
# sources_backup
#  Backup sources
##################################################################
sources_backup_loop() {
   local error=0
   local item_error=0
   local source=
   local depth=
   local inc=
   local target=
   local current_date=
   local dir=

   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN "Backup Data" >> $BAK_OUTPUT
   for index in `seq 0 1 $((${#BAK_SOURCES_CONFIG_SOURCE[@]} - 1))`; do
      source="${BAK_SOURCES_CONFIG_SOURCE[$index]}"
      if echo "$source" | $GREP_BIN -q "\$"; then eval source="$source"; fi
      depth=${BAK_SOURCES_CONFIG_DEPTH[$index]}
      inc=${BAK_SOURCES_CONFIG_INC[$index]}
      target="$BAK_TEMP_PATH"
      $ECHO_BIN "   '$source' (depth=$depth, inc=$inc):" >> $BAK_OUTPUT
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
      current_date=`$DATE_BIN`
      $ECHO_BIN " START $current_date" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " ACTION Data ($index) : $source " >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " CMD : '$TAR_BIN' : source='$source', depth=$depth, inc=$inc" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED

      # Check depth
      if [ $depth -gt 0 ]; then
         while IFS= read -r dir; do
            source_backup "$dir" "$target" $inc
            item_error=$?
            if [ $item_error -ne 0 ]; then
               $ECHO_BIN "   ERROR: Source '$dir' ends with error = $item_error" >> $BAK_OUTPUT
               error=1;
            fi
         done < <($FIND_BIN "$source" -maxdepth $depth -mindepth $depth -type d -not -name ".*")
      else
         source_backup "$source" "$target" $inc
         item_error=$?
         if [ $item_error -ne 0 ]; then
            $ECHO_BIN "   ERROR: Source '$source' ends with error = $item_error" >> $BAK_OUTPUT
            error=1;
         fi
      fi
   done
   return $error
}

##################################################################
# source_backup
#  Backup a directory
##################################################################
source_backup() {
   local error=0
   local source_error=0
   local dir=$1
   local target=$2
   local inc=$3
   local name=
   local tarfile=
   local incfile=
   local local_incfile=
   local remote_incfile=
   local extra=
   local size=0

   if [ -e "$dir" ] && [ -e "$target" ]; then
      name=${dir/\//}
      name=${name//\//_}
      tarfile="$target/${BAK_DATE}-${name}-backup.tar.bz2"
      incfile="${name}-inc-log.dat"
      local_incfile="$BAK_HISTORICAL_PATH/$incfile"
      remote_incfile="$target/$incfile"

      $ECHO_BIN -n "      '$target' <- '$dir'" >> $BAK_OUTPUT
      $ECHO_BIN " CMD : dir_size '$dir'" >> $BAK_OUTPUT_EXTENDED
      size=`dir_size $dir`
      $ECHO_BIN -n " ($size) ... " >> $BAK_OUTPUT
      $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED

      if [ $inc -eq 1 ]; then
         extra="-g $local_incfile"
      fi

      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$TAR_BIN $extra $TAR_OPTS '$tarfile' '$dir' ... " >> $BAK_OUTPUT
      else
         $ECHO_BIN " CMD : $TAR_BIN $extra $TAR_OPTS '$tarfile' '$dir'" >> $BAK_OUTPUT_EXTENDED
         $TAR_BIN $extra $TAR_OPTS "$tarfile" "$dir" >> $BAK_OUTPUT_EXTENDED 2>&1
      fi
      source_error=$?

      if [ $inc -eq 1 ]; then
         if [ $source_error -eq 0 ] || [ $source_error -eq 1 ]; then
            # Copy inc file to target
            if [ $BAK_DEBUG -eq 1 ]; then
               source_error=0
            else
               $ECHO_BIN " CMD : $CP_BIN '$local_incfile' '$remote_incfile'" >> $BAK_OUTPUT_EXTENDED
               $CP_BIN "$local_incfile" "$remote_incfile" >> $BAK_OUTPUT_EXTENDED 2>&1
            fi
         fi
      fi

      if [ $source_error -eq 0 ]; then
         $ECHO_BIN -n "OK" >> $BAK_OUTPUT
         $ECHO_BIN " CMD : file_size '$tarfile'" >> $BAK_OUTPUT_EXTENDED
         size=`file_size "$tarfile"`
         $ECHO_BIN " ($size)" >> $BAK_OUTPUT
         $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
      elif [ $source_error -eq 1 ]; then
         $ECHO_BIN -n "WARNING" >> $BAK_OUTPUT
         $ECHO_BIN " CMD : file_size '$tarfile'" >> $BAK_OUTPUT_EXTENDED
         size=`file_size "$tarfile"`
         $ECHO_BIN " ($size, some files were changed while being archived)" >> $BAK_OUTPUT
         $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
      else
         $ECHO_BIN "FAIL (error = $source_error)" >> $BAK_OUTPUT
         error=$source_error
      fi

   else
      $ECHO_BIN "ERROR : Bad parameters in 'source_backup' DIR = '$DIR', TARGET = '$TARGET', INC = '$INC'" >> $BAK_OUTPUT
      error=1
   fi

   # Process this backup
   if [ $error -eq 0 ]; then
      backup_process "$target" "${BAK_DATE}-$name"
      error=$?
   fi

   return $error
}

##################################################################
# backup_process
#  Process a backup
#  from a directory where all files are already copied
##################################################################
backup_process() {
   local error=0
   local be_error=0
   local dir=$1
   local name=$2
   local file_to_upload=
   local be=
   local bef=
   local tarfile=
   local encfile=
   local size=0

   if [ -e "$dir" ] && [ -n "$name" ]; then
      $ECHO_BIN " CMD : dir_size '$dir'" >> $BAK_OUTPUT_EXTENDED
      size=`dir_size "$dir"`
      $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN "         Process Backup '$name' ($size)" >> $BAK_OUTPUT
      # Compress $dir into output dir
      $ECHO_BIN -n "         -> Compress backup files ... " >> $BAK_OUTPUT
      tarfile="$BAK_OUTPUT_PATH/$name.tar.gz"
      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$COMPRESS_BIN '$tarfile' '$dir' ... " >> $BAK_OUTPUT
      else
         $ECHO_BIN " CMD : $COMPRESS_BIN '$tarfile' '$dir'" >> $BAK_OUTPUT_EXTENDED
         $COMPRESS_BIN "$tarfile" "$dir" >> $BAK_OUTPUT_EXTENDED 2>&1
      fi
      error=$?
      if [ $error -eq 0 ]; then
         $ECHO_BIN -n "OK" >> $BAK_OUTPUT
         $ECHO_BIN " CMD : file_size '$tarfile'" >> $BAK_OUTPUT_EXTENDED
         size=`file_size $tarfile`
         $ECHO_BIN " ($size)" >> $BAK_OUTPUT
         $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
      else
         $ECHO_BIN "FAIL (error = $error)" >> $BAK_OUTPUT;
      fi

      file_to_upload="$tarfile"

      # Delete all files in $dir
      $ECHO_BIN -n "         -> Delete backup files ... " >> $BAK_OUTPUT
      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$RM_BIN '$dir'/* ... " >> $BAK_OUTPUT
      else
         $ECHO_BIN " CMD : $RM_BIN '$dir'/*" >> $BAK_OUTPUT_EXTENDED
         $RM_BIN "$dir"/* >> $BAK_OUTPUT_EXTENDED 2>&1
      fi
      $ECHO_BIN "OK" >> $BAK_OUTPUT

      if [ $error -eq 0 ]; then
         if [ $BAK_ENCRYPT -eq 1 ]; then
            # Encrypt backup
            $ECHO_BIN -n "         -> Encrypt backup ... " >> $BAK_OUTPUT
            encfile="$BAK_OUTPUT_PATH/$name.tar.gz.enc"
            if [ $BAK_DEBUG -eq 1 ]; then
               $ECHO_BIN -n "$OPENSSL_ENC_BIN -in '$tarfile' -out '$encfile' ... " >> $BAK_OUTPUT
            else
               $ECHO_BIN " CMD : $OPENSSL_ENC_BIN -in '$tarfile' -out '$encfile'" >> $BAK_OUTPUT_EXTENDED
               $OPENSSL_ENC_BIN -in "$tarfile" -out "$encfile" >> $BAK_OUTPUT_EXTENDED 2>&1
            fi
            error=$?
            if [ $error -eq 0 ]; then
               $ECHO_BIN -n "OK" >> $BAK_OUTPUT
               $ECHO_BIN " CMD : file_size '$encfile'" >> $BAK_OUTPUT_EXTENDED
               size=`file_size $encfile`
               $ECHO_BIN " ($size)" >> $BAK_OUTPUT
               $ECHO_BIN " SIZE : $size" >> $BAK_OUTPUT_EXTENDED
               if [ $BAK_DEBUG -eq 0 ]; then
                  $ECHO_BIN " CMD : $RM_BIN '$tarfile'" >> $BAK_OUTPUT_EXTENDED
                  $RM_BIN "$tarfile" >> $BAK_OUTPUT_EXTENDED 2>&1
               fi
               file_to_upload="$encfile"
            else $ECHO_BIN "FAIL (error = $error)" >> $BAK_OUTPUT; fi
         else
            encfile="$tarfile"
            file_to_upload="$encfile"
         fi
      fi

      if [ $error -eq 0 ]; then
         # Copy to each remote backend
         if [ -n "$BAK_REMOTE_BACKENDS" ]; then
            $ECHO_BIN -n "         -> Copy to backends ..." >> $BAK_OUTPUT
         fi
         for be in $BAK_REMOTE_BACKENDS; do
            bef="${be}_put"
            if is_function $bef; then
               $ECHO_BIN -n " $be " >> $BAK_OUTPUT
               try=0
               while [ $try -lt $BAK_BACKEND_MAX_RETRIES ]; do
                  if [ $BAK_DEBUG -eq 1 ]; then
                     $ECHO_BIN  -n "$bef '$file_to_upload' " >> $BAK_OUTPUT
                  else
                     $bef "$file_to_upload"
                  fi
                  be_error=$?
                  if [ $be_error -eq 0 ]; then
                     $ECHO_BIN -n "[OK]" >> $BAK_OUTPUT
                     break;
                  else
                     $ECHO_BIN -n "[ERROR = $be_error]" >> $BAK_OUTPUT
                     try=$((try + 1))
                  fi
               done
               if [ $be_error -ne 0 ]; then error=$be_error; fi
            fi
         done
         $ECHO_BIN >> $BAK_OUTPUT

         # Move to local backend or delete
         if [ "$BAK_LOCAL_BACKENDS" == "local" ]; then
            $ECHO_BIN -n "         -> Move to local backend ... " >> $BAK_OUTPUT
            if [ $BAK_DEBUG -eq 1 ]; then
               $ECHO_BIN -n "$MV_BIN '$file_to_upload' '$BAK_LOCAL_PATH' ... " >> $BAK_OUTPUT
            else
               $ECHO_BIN " CMD : $MV_BIN '$file_to_upload' '$BAK_LOCAL_PATH'" >> $BAK_OUTPUT_EXTENDED
               $MV_BIN "$file_to_upload" "$BAK_LOCAL_PATH" >> $BAK_OUTPUT_EXTENDED 2>&1
            fi
         else
            $ECHO_BIN -n "         -> Delete backup ... " >> $BAK_OUTPUT
            if [ $BAK_DEBUG -eq 1 ]; then
               $ECHO_BIN -n "$RM_BIN '$file_to_upload' ... " >> $BAK_OUTPUT
            else
               $ECHO_BIN " CMD : $RM_BIN '$file_to_upload'" >> $BAK_OUTPUT_EXTENDED
               $RM_BIN "$file_to_upload" >> $BAK_OUTPUT_EXTENDED 2>&1
            fi
         fi
         $ECHO_BIN "OK" >> $BAK_OUTPUT
      fi
   else
      $ECHO_BIN "ERROR : Bad parameters in 'backup_process' DIR = '$DIR', NAME = '$NAME'" >> $BAK_OUTPUT
   fi
   return $error
}

##################################################################
# snapshot
#  Perform a snapshot
#  It depends on backends
##################################################################
snapshot() {
   local error=0
   local be_error=0

   if [ $BAK_ENABLED -eq 0 ]; then
      config_show
      $ECHO_BIN "INFO : Backup is disabled by config. Please modify configuration in order to perform a snapshot"
      $ECHO_BIN "INFO : Read README.md file to further information about Configuration"
      return 1
   fi

   # Check log directory and create it (if needed)
   log_directory_create

   # Start log
   log_start_print "SNAPSHOT"

   # Mount devices (if any)
   mount_devices

   # Check directories and create them (if needed)
   directories_create

   # Check lock
   if ! lock_check_and_set; then
      log_end_print "BACKUP"
      mail_error_send
      return 1
   fi

   # Remove historical files
   $ECHO_BIN "Deleting historical files at '$BAK_HISTORICAL_PATH'" >> $BAK_OUTPUT
   $RM_BIN "$BAK_HISTORICAL_PATH"/*

   for backend in $BAK_BACKENDS; do
      bef="${backend}_snapshot"
      if is_function $bef; then
         $bef
         be_error=$?
         if [ $be_error -ne 0 ]; then error=1; fi
      fi
   done

   # UnMount devices (if any)
   umount_devices

   # End log
   log_end_print "SNAPSHOT"

   # Send report email
   if [ $error -eq 0 ]; then
      mail_log_send
   else
      mail_error_send
   fi

   return $error
}

##################################################################
# restore
#  Restore a backup file
##################################################################
restore() {
   $ECHO_BIN "ERROR : Not implemented yet"
   return 1
}

##################################################################
# list
#  List the contents of a backup file
##################################################################
list() {
   $ECHO_BIN "ERROR : Not implemented yet"
   return 1
}

##################################################################
# source_config_read
#  Read sources configuration
##################################################################
source_config_read(){
   local i=0
   local line=

   if [ ! -f "$BAK_OUTPUT" ]; then BAK_OUTPUT=$BAK_NULL_OUTPUT; fi

   $ECHO_BIN -n "Reading configuration..." >> $BAK_OUTPUT
   if [ -e "$1" ]; then
      while read line; do
         [[ ${line:0:1} == "#" ]] && continue
         [[ -z "$line" ]] && continue
         BAK_SOURCES_CONFIG_SOURCE[$i]=`$ECHO_BIN $line | $CUT_BIN -d',' -f1`
         BAK_SOURCES_CONFIG_DEPTH[$i]=`$ECHO_BIN $line | $CUT_BIN -d',' -f2`
         BAK_SOURCES_CONFIG_INC[$i]=`$ECHO_BIN $line | $CUT_BIN -d',' -f3`
         i=$(($i + 1))
      done < "$1"
      $ECHO_BIN " $i items" >> $BAK_OUTPUT
      return 0
   fi
   $ECHO_BIN " ERR: File not found" >> $BAK_OUTPUT
   return 1
}

##################################################################
# mail_from_to_write
#  Write FROM an TO email headers
##################################################################
mail_from_to_write() {
   $ECHO_BIN "To: $BAK_MAIL_TO" > $BAK_MAIL_TEMP_FILE
   if [ -n "$BAK_MAIL_CC" ]; then $ECHO_BIN "Cc: $BAK_MAIL_CC" >> $BAK_MAIL_TEMP_FILE; fi
   $ECHO_BIN "From: $BAK_MAIL_FROM" >> $BAK_MAIL_TEMP_FILE
}

##################################################################
# mail_send
#  Send email
##################################################################
mail_send() {
   $ECHO_BIN "MIME-Version: 1.0" >> $BAK_MAIL_TEMP_FILE
   $ECHO_BIN "Content-Type: text/plain; charset=UTF-8" >> $BAK_MAIL_TEMP_FILE
   $ECHO_BIN "Content-Transfer-Encoding: 8bit" >> $BAK_MAIL_TEMP_FILE
   $ECHO_BIN >> $BAK_MAIL_TEMP_FILE
   $CAT_BIN $BAK_OUTPUT >> $BAK_MAIL_TEMP_FILE
   if [ $1 -eq 1 ] && [ -n "$BAK_MAIL_TO" ]; then
      $CAT_BIN $BAK_MAIL_TEMP_FILE | $SENDMAIL_BIN -f $BAK_MAIL_FROM_USER -t $BAK_MAIL_TO
      $CP_BIN $BAK_MAIL_TEMP_FILE $BAK_MAIL_LAST_FILE
      $RM_BIN $BAK_MAIL_TEMP_FILE
   fi
}

##################################################################
# mail_error_send
#  Send an error email
##################################################################
mail_error_send() {
   mail_from_to_write
   $ECHO_BIN "X-Backup-Response: failure" >> $BAK_MAIL_TEMP_FILE
   $ECHO_BIN "Subject: $BAK_MAIL_SUBJECT_ERR" >> $BAK_MAIL_TEMP_FILE
   mail_send $BAK_SEND_MAIL_ERR
}

##################################################################
# mail_log_send
#  Send an log email
##################################################################
mail_log_send() {
   mail_from_to_write
   $ECHO_BIN "X-Backup-Response: success" >> $BAK_MAIL_TEMP_FILE
   $ECHO_BIN "Subject: $BAK_MAIL_SUBJECT_LOG" >> $BAK_MAIL_TEMP_FILE
   mail_send $BAK_SEND_MAIL_LOG
}

##################################################################
# info_get
#  Local and backend usage info
##################################################################
info_get() {
   local index=
   local name=
   local device=
   local values=

   $ECHO_BIN >> $BAK_OUTPUT
   $ECHO_BIN    "========================================================" >> $BAK_OUTPUT
   $ECHO_BIN -e " DEVICE         \tTOTAL \tUSED  \tFREE  \tPERCENT" >> $BAK_OUTPUT
   $ECHO_BIN    "========================================================" >> $BAK_OUTPUT
   for index in `seq 0 1 $((${#BAK_LOCAL_INFO_DEVICES[@]} - 1))`; do
      name=`$ECHO_BIN ${BAK_LOCAL_INFO_DEVICES[$index]} | $CUT_BIN -d',' -f1`
      device=`$ECHO_BIN ${BAK_LOCAL_INFO_DEVICES[$index]} | $CUT_BIN -d',' -f2`
      values=`$DF_BIN -h | $GREP_BIN $device`
      set -- $values
      $ECHO_BIN -e " $name ($device) \t$2 \t$3 \t$4 \t$5" >> $BAK_OUTPUT
   done
   $ECHO_BIN    "--------------------------------------------------------" >> $BAK_OUTPUT
   #########################################
   # TODO : Show info for each backend #####
   #########################################
   $ECHO_BIN    "========================================================" >> $BAK_OUTPUT
}

##################################################################
# log_start_print
#  Print log header
##################################################################
log_start_print() {
   $ECHO_BIN "----------------------------------------------------------------" > $BAK_OUTPUT;
   $ECHO_BIN -n "$1 START ($$) - " >> $BAK_OUTPUT;
   $ECHO_BIN $BAK_START_DATE >> $BAK_OUTPUT;
   $ECHO_BIN "----------------------------------------------------------------" >> $BAK_OUTPUT;
   $ECHO_BIN >> $BAK_OUTPUT;
}


##################################################################
# log_end_print
#  Print log footer
##################################################################
log_end_print() {
   BAK_END_DATE=`$DATE_BIN`
   $ECHO_BIN >> $BAK_OUTPUT;
   $ECHO_BIN "----------------------------------------------------------------" >> $BAK_OUTPUT;
   $ECHO_BIN -n "$1 END   ($$) - " >> $BAK_OUTPUT;
   $ECHO_BIN $BAK_END_DATE >> $BAK_OUTPUT;
   $ECHO_BIN "----------------------------------------------------------------" >> $BAK_OUTPUT;
}

##################################################################
# lock_check
#  Check if another backup proccess is executing
##################################################################
lock_check_and_set() {
   if [ -f $BAK_LOCK ]; then
      pid=`$CAT_BIN "$BAK_LOCK"`
      if $PID_CHECK_BIN $pid > $BAK_NULL_OUTPUT 2>&1; then
         $ECHO_BIN "ERROR : Another backup process detected on pid = $pid" >> $BAK_OUTPUT
         return 1
      else
         lock_set
      fi
   else
      lock_set
   fi
   return 0
}

lock_set() {
   trap "{ lock_release; }" EXIT
   $ECHO_BIN $$ > "$BAK_LOCK"
}

lock_release() {
   $RM_BIN "$BAK_LOCK"
   $RM_BIN "$BAK_TEMP_PATH"/*
   $RM_BIN "$BAK_OUTPUT_PATH"/*
}


##################################################################
# directories_create
#  Create directories (if needed)
##################################################################
log_directory_create() {
   # Create log directory (if needed)
   if [ ! -d "$BAK_LOG_PATH" ]; then
      $ECHO_BIN "INFO : Creating log dir '$BAK_LOG_PATH'"
      $MKDIR_BIN "$BAK_LOG_PATH"
   fi
}

directories_create() {

   # Create tmp directory (if needed)
   if [ ! -d "$BAK_TEMP_PATH" ]; then
      $ECHO_BIN "INFO : Creating temp dir '$BAK_TEMP_PATH'"
      $MKDIR_BIN "$BAK_TEMP_PATH"
   fi

   # Create output directory (if needed)
   if [ ! -d "$BAK_OUTPUT_PATH" ]; then
      $ECHO_BIN "INFO : Creating output dir '$BAK_OUTPUT_PATH'"
      $MKDIR_BIN "$BAK_OUTPUT_PATH"
   fi

   # Create historical directory (if needed)
   if [ ! -d "$BAK_HISTORICAL_PATH" ]; then
      $ECHO_BIN "INFO : Creating historical dir '$BAK_HISTORICAL_PATH'"
      $MKDIR_BIN "$BAK_HISTORICAL_PATH"
   fi

   # Create MySQL database directory (if needed)
   if [ ! -d "$BAK_MYSQL_DATABASE_PATH" ]; then
      $ECHO_BIN "INFO : Creating MySQL database dir '$BAK_MYSQL_DATABASE_PATH'"
      $MKDIR_BIN "$BAK_MYSQL_DATABASE_PATH"
   fi

   # Create PostgreSQL database directory (if needed)
   if [ ! -d "$BAK_POSTGRESQL_DATABASE_PATH" ]; then
      $ECHO_BIN "INFO : Creating PostgreSQL database dir '$BAK_POSTGRESQL_DATABASE_PATH'"
      $MKDIR_BIN "$BAK_POSTGRESQL_DATABASE_PATH"
   fi

   # Create server config directory (if needed)
   if [ ! -d "$BAK_CONFIG_SERVER_PATH" ]; then
      $ECHO_BIN "INFO : Creating server config dir '$BAK_CONFIG_SERVER_PATH'"
      $MKDIR_BIN "$BAK_CONFIG_SERVER_PATH"
   fi

   if [ -n "$BAK_LOCAL_PATH" ] && [ ! -d "$BAK_LOCAL_PATH" ]; then
      $ECHO_BIN "INFO : Creating local backend dir '$BAK_LOCAL_PATH'"
      $MKDIR_BIN "$BAK_LOCAL_PATH"
   fi

}

##################################################################
# contains <array> <value>
#  Return true if array contains value
#  Sample :
#     if $(contains "${SAMPLE_ARRAY[@]}" "$value"); then
#        do_something
#     fi
##################################################################
contains() {
    local n=$#
    local value=${!n}
    if [ $n -gt 1 ]; then
       for ((i=1;i < $#;i++)) {
           if [ "${!i}" == "${value}" ]; then
               return 0
           fi
       }
       return 1
   else
      return 1
   fi
}

file_size() {
   local file=$1
   local size=0

   if [ -f "$file" ]; then
      size=`$FILE_SIZE_BIN "$file" | $CUT_BIN -d' ' -f1`
   fi

   $ECHO_BIN "$size"
}

dir_size() {
   local dir=$1
   local size=0

   if [ -d "$dir" ]; then
      size=`$DIR_SIZE_BIN "$dir" | $CUT_BIN -f1`
   fi

   $ECHO_BIN "$size"
}

mount_action() {
   local error=0
   local merror=0
   local mtype=
   local action=$1

   if [ -n "$BAK_MOUNT_POINTS_ENABLED" ]; then
      for mp in $BAK_MOUNT_POINTS_ENABLED; do
         $ECHO_BIN -n " $mp ... " >> $BAK_OUTPUT
         if [ ${BAK_MOUNT_POINTS[$mp,type]+_} ]; then
            mtype=${BAK_MOUNT_POINTS[$mp,type]}
            mf="${action}_${mtype}"
            if is_function $mf; then
               $mf $mp
               merror=$?
               if [ $merror -ne 0 ]; then
                  $ECHO_BIN " - ERROR ($merror)" >> $BAK_OUTPUT;
               else
                  $ECHO_BIN " - OK" >> $BAK_OUTPUT;
               fi
            else
               $ECHO_BIN "ERROR : Mount type '$mtype' is not supported, '$mf' function not found" >> $BAK_OUTPUT
               merror=1
            fi
         else
            $ECHO_BIN "ERROR : Mount type is not defined" >> $BAK_OUTPUT
            merror=1
         fi
         if [ $merror -ne 0 ]; then error=1; fi
      done
   else
      $ECHO_BIN " No mount points defined" >> $BAK_OUTPUT
   fi

   return $error
}

mount_devices() {
   $ECHO_BIN "Mount devices" >> $BAK_OUTPUT
   mount_action 'mount'
   error=$?

   if [ $error -eq 0 ]; then
      for backend in $BAK_BACKENDS; do
         bef="${backend}_mount"
         if is_function $bef; then
            $bef
         fi
      done
   fi

   return $error
}

umount_devices() {
   $ECHO_BIN "Un-mount devices" >> $BAK_OUTPUT

   for backend in $BAK_BACKENDS; do
      bef="${backend}_umount"
      if is_function $bef; then
         $bef
      fi
   done

   mount_action 'umount'
   return $?
}

mount_nfs() {
   local mp=$1
   local server=
   local rpath=
   local lpath=

   # Check mount command exists and executable
   if [ ! -x "$MOUNT_NFS_FILE" ]; then
      $ECHO_BIN -n "ERROR : NFS mount binary '$MOUNT_NFS_FILE' not found or not executable" >> $BAK_OUTPUT
      return 1
   fi

   server=${BAK_MOUNT_POINTS[$mp,server]}
   rpath=${BAK_MOUNT_POINTS[$mp,remote]}
   lpath=${BAK_MOUNT_POINTS[$mp,local]}

   if [ ! -d "$lpath" ]; then
      $ECHO_BIN -n "ERROR : Local path '$lpath' not found or not a directory" >> $BAK_OUTPUT
      return 2
   fi

   if $MOUNT_BIN | $GREP_BIN -q "$lpath"; then
      $ECHO_BIN -n "WARNING : A device is already mounted at '$lpath'" >> $BAK_OUTPUT
      return 0
   fi

   $ECHO_BIN "MOUNT : '$MOUNT_NFS_BIN' '${server}:${rpath}' '${lpath}'" >> $BAK_OUTPUT_EXTENDED
   "$MOUNT_NFS_BIN" "${server}:${rpath}" "${lpath}" >> $BAK_OUTPUT_EXTENDED 2>&1

   return $?
}

umount_nfs() {
   local mp=$1
   local lpath=

   # Check mount command exists and executable
   if [ ! -x "$UMOUNT_NFS_FILE" ]; then
      $ECHO_BIN -n "ERROR : NFS umount binary '$UMOUNT_NFS_FILE' not found or not executable" >> $BAK_OUTPUT
      return 1
   fi

   lpath=${BAK_MOUNT_POINTS[$mp,local]}

   if [ ! -d "$lpath" ]; then
      $ECHO_BIN -n "ERROR : Local path '$lpath' not found or not a directory" >> $BAK_OUTPUT
      return 2
   fi

   if ! $MOUNT_BIN | $GREP_BIN -q "$lpath"; then
      $ECHO_BIN -n "WARNING : Device is not mounted at '$lpath'" >> $BAK_OUTPUT
      return 0
   fi

   $ECHO_BIN "UMOUNT : '$UMOUNT_BIN' '${lpath}'" >> $BAK_OUTPUT_EXTENDED
   "$UMOUNT_BIN" "${lpath}" >> $BAK_OUTPUT_EXTENDED 2>&1

   return 0
}

environment_check() {
   local index=0
   local error=0
   local be_error=0
   local file=
   local bef=

   for index in `seq 0 1 $((${#BAK_ENVIRONMENT_LIST[@]} - 1))`; do
      file="${BAK_ENVIRONMENT_LIST[$index]}"
      if [ ! -x "$file" ]; then
         $ECHO_BIN "ERROR : Environment checking : '$file' not found or not executable" 2>&1
         exit 1
      fi
   done

   for backend in $BAK_BACKENDS; do
      bef="${backend}_environment_check"
      if is_function $bef; then
         $bef
         be_error=$?
         if [ $be_error -ne 0 ]; then error=1; fi
      fi
   done

   if [ $error -ne 0 ]; then exit $error; fi
}

executable_set() {
   local file=$1

   if [ ! -f "$file" ]; then echo "ERROR : File '$file' not found. Please download again"; exit 1; fi
   if [ ! -x "$file" ]; then echo "INFO : Setting '$file' executable"; chmod +x "$file"; fi;
}

license_show() {
   cat << LICENSE
Server-Backup v$BAK_VERSION
Copyright (C) 2012 Antonio Espinosa <aespinosa@teachnova.com> - TeachNova
This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it GPLv3 license conditions. Read LICENSE.md for more details.

LICENSE
}

version_show() {
   license_show
}


help_show() {
   license_show
   cat << HELP
Backup system for Dedicated Servers or EC2 into different backends : S3, LOCAL, FTP, SFTP, USBHD, WEBDAV.
Also support backup encryption using any algorithm supported by OpenSSL library.

Usage : $0 [options]

Options:
   -v | --version : Show version
   -h | --help    : Show this help
   -c | --config  : Show current configuration

Call with no options to execute backup process. With no options, no
output is expected, but errors.

HELP
}

config_show() {
   local error=0
   local be_error=0
   local i=
   local databases=
   local extra=
   local config=
   local bef=
   local index=0
   local server=
   local data=
   local encstatus=
   local status=

   license_show

   BAK_OUTPUT=/dev/stdout
   BAK_OUTPUT_EXTENDED=/dev/null

   # Mount devices (if any)
   mount_devices

   if [ $BAK_ENCRYPT -eq 1 ]; then
      if [ -f "$BAK_ENCRYPT_KEY_FILE" ]; then
         enckey=`cat $BAK_ENCRYPT_KEY_FILE`
         if [ ${#enckey} -lt 32 ]; then
            encstatus="ERROR : Key file is too short, please set at least a 32 character key"
            error=1
         else
            encstatus="OK"
         fi
      else
         encstatus="ERROR : Key file '$BAK_ENCRYPT_KEY_FILE' not found"
         error=1
      fi
   else
      encstatus="OK"
   fi

   if [ $BAK_MYSQL_DATABASE_ENABLED -eq 0 ]; then
      mysql_databases='Disabled by configuration'
   elif [ $BAK_MYSQL_DATABASE_ENABLED -eq 2 ]; then
      mysql_databases='Disabled because no mysql or mysqldump binaries found'
   else
      for i in $(eval $BAK_MYSQL_DATABASE_LIST_CMD);
      do
         if $(contains "${BAK_MYSQL_DATABASE_DISALLOW[@]}" "$i"); then
            continue
         fi
         if [ $BAK_MYSQL_DATABASE_ALLOW_ALL -eq 1 ] || $(contains "${BAK_MYSQL_DATABASE_ALLOW[@]}" "$i"); then
            if [ -z "$mysql_databases" ]; then mysql_databases="$i";
            else mysql_databases=`$ECHO_BIN -e "${mysql_databases}\n${i}"`; fi
         fi
      done
   fi

   if [ $BAK_POSTGRESQL_DATABASE_ENABLED -eq 0 ]; then
      postgresql_databases='Disabled by configuration'
   elif [ $BAK_POSTGRESQL_DATABASE_ENABLED -eq 2 ]; then
      postgresql_databases='Disabled because no psql or pgdump or pg_lscluster binaries found'
   else
      for i in $(eval $BAK_POSTGRESQL_DATABASE_LIST_CMD);
      do
         if $(contains "${BAK_POSTGRESQL_DATABASE_DISALLOW[@]}" "$i"); then
            continue
         fi
         if [ $BAK_POSTGRESQL_DATABASE_ALLOW_ALL -eq 1 ] || $(contains "${BAK_POSTGRESQL_DATABASE_ALLOW[@]}" "$i"); then
            if [ -z "$postgresql_databases" ]; then postgresql_databases="$i";
            else postgresql_databases=`$ECHO_BIN -e "${postgresql_databases}\n${i}"`; fi
         fi
      done
   fi

   for index in `seq 0 1 $((${#BAK_CONFIG_SERVER_SOURCES[@]} - 1))`; do
      path="${BAK_CONFIG_SERVER_SOURCES[$index]}"
      if [ -d "$path" ]; then status="OK"; else status="NOT FOUND"; error=1; fi
      if [ -z "$server" ]; then server="$path - $status";
      else server=`$ECHO_BIN -e "${server}\n$path - $status"`; fi
   done

   if ! source_config_read "$BAK_SOURCES_CONFIG_FILE"; then
      data="ERROR: Reading configuration (config file = $BAK_SOURCES_CONFIG_FILE)"
   else
      for index in `seq 0 1 $((${#BAK_SOURCES_CONFIG_SOURCE[@]} - 1))`; do
         path="${BAK_SOURCES_CONFIG_SOURCE[$index]}"
         if echo "$path" | grep -q "\$"; then eval path="$path"; fi
         depth=${BAK_SOURCES_CONFIG_DEPTH[$index]}
         inc=${BAK_SOURCES_CONFIG_INC[$index]}
         if [ -d "$path" ]; then status="OK"; else status="NOT FOUND"; error=1; fi
         if [ -z "$data" ]; then data="$path (depth = $depth, inc = $inc) - $status";
         else data=`$ECHO_BIN -e "${data}\n$path (depth = $depth, inc = $inc) - $status"`; fi
         if [ "$status" == "OK" ] && [ $depth -gt 0 ]; then
            while IFS= read -r dir; do
               data=`$ECHO_BIN -e "${data}\n   $dir"`
            done < <($FIND_BIN "$path" -maxdepth $depth -mindepth $depth -type d -not -name ".*")
         fi
      done
   fi

   for backend in $BAK_BACKENDS; do
      bef="${backend}_snapshot"
      if is_function $bef; then
         $bef
         be_error=$?
         if [ $be_error -ne 0 ]; then error=1; fi
      fi
   done

   # Extra configuration, backends
   for backend in $BAK_BACKENDS; do
      bef="${backend}_config_show"
      if is_function $bef; then
         config=`$bef`
         be_error=$?
         if [ $be_error -ne 0 ]; then error=1; fi
         if [ -z "$extra" ]; then extra="${config}";
         else extra=`$ECHO_BIN -e "${extra}\n\n${config}"`; fi
      fi
   done

   if [ $error -eq 0 ]; then
      status="OK : Server-Backup is successful configurated"
   else
      status="WARNING : Some errors detected, please review your configuration"
   fi

   cat << CONFIG
Paths:
------------------------------------------------
Configuration  : $BAK_CONFIG_PATH
Data           : $BAK_DATA_PATH

General config: (1 = enabled, 0 = disabled)
-------------------------------------------------
Enabled        : $BAK_ENABLED
Debug          : $BAK_DEBUG
Encryption     : $BAK_ENCRYPT - $encstatus

Email on Error : $BAK_SEND_MAIL_ERR
Email on OK    : $BAK_SEND_MAIL_LOG
Email From     : $BAK_MAIL_FROM_USER
Email To       : $BAK_MAIL_TO
Email Cc       : $BAK_MAIL_CC

Backends       : $BAK_BACKENDS

Server configuration:
-------------------------------------------------
$server

MySQL Databases:
-------------------------------------------------
$mysql_databases

PostgreSQL Databases:
-------------------------------------------------
$postgresql_databases

Data:
-------------------------------------------------
$data

$extra

--> STATUS : $status

CONFIG

   BAK_OUTPUT=/dev/stdout
   BAK_OUTPUT_EXTENDED=/dev/null

   # UnMount devices (if any)
   umount_devices

}
