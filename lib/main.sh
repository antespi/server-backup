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

BAK_TEMP_DIR=tmp
BAK_OUTPUT_DIR=out
BAK_HISTORICAL_DIR=historical

BAK_TEMP_PATH=$BAK_DATA_PATH/$BAK_TEMP_DIR
BAK_OUTPUT_PATH=$BAK_DATA_PATH/$BAK_OUTPUT_DIR
BAK_HISTORICAL_PATH=$BAK_DATA_PATH/$BAK_HISTORICAL_DIR

##################################################################
# BACKUP Output

BAK_OUTPUT=$BAK_PATH/$BAK_LOG_DIR/bak_log_$BAK_DATE.txt
BAK_OUTPUT_EXTENDED=$BAK_PATH/$BAK_LOG_DIR/bak_log_${BAK_DATE}_ext.txt
# BAK_OUTPUT=/dev/stdout
BAK_NULL_OUTPUT=/dev/null

##################################################################
# BACKUP Data sources

BAK_SOURCES_CONFIG_FILE=$BAK_PATH/$BAK_CONFIG_DIR/sources.conf

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

SR_FILE="$BAK_LIB_PATH/sr.sh"
SR_BIN="$SR_FILE -y"

MKDIR_FILE=/bin/mkdir
MKDIR_BIN="$MKDIR_FILE -p"

CAT_FILE=/bin/cat
CAT_BIN="$CAT_FILE"

FIND_FILE=/usr/bin/find
FIND_BIN="$FIND_FILE"

GREP_FILE=/bin/grep
GREP_BIN="$GREP_FILE"

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

BAK_ENVIRONMENT_LIST=(
   "$TAR_FILE"
   "$RM_FILE"
   "$MV_FILE"
   "$CP_FILE"
   "$SR_FILE"
   "$MKDIR_FILE"
   "$CAT_FILE"
   "$FIND_FILE"
   "$GREP_FILE"
   "$DF_FILE"
   "$LS_FILE"
   "$DU_FILE"
   "$SENDMAIL_FILE"
   "$OPENSSL_FILE"
   "$ECHO_FILE"
   "$CUT_FILE"
   "$CHMOD_FILE"
   "$CHOWN_FILE"
)

##################################################################
# BACKUP Library functions


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
         $RM_BIN "$file"
      done
   else
      $ECHO_BIN "ERROR : Bad parameters in 'old_files_rm' PATH = '$PATH', DAYS = '$DAYS'" >> $BAK_OUTPUT
   fi
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
   for i in $(eval $BAK_MYSQL_DATABASE_LIST_CMD);
   do
      if $(contains "${BAK_DATABASE_DISALLOW[@]}" "$i"); then
         continue
      fi

      $ECHO_BIN -n "   $i ... " >> $BAK_OUTPUT

      if [ $BAK_DATABASE_ALLOW_ALL -eq 1 ] || $(contains "${BAK_DATABASE_ALLOW[@]}" "$i"); then
         file="$BAK_DATABASE_PATH/${BAK_DATE}-${i}.sql"
         if [ $BAK_DEBUG -eq 1 ]; then
            $ECHO_BIN -n "$BAK_MYSQL_DATABASE_BACKUP_CMD $i > '$file' ... " >> $BAK_OUTPUT
         else
            $BAK_MYSQL_DATABASE_BACKUP_CMD $i > "$file"
         fi
         db_error=$?
         if [ $db_error -eq 0 ];then
            $ECHO_BIN -n "OK" >> $BAK_OUTPUT
            size=`file_size $file`
            $ECHO_BIN " ($size)" >> $BAK_OUTPUT
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
      backup_process "$BAK_DATABASE_PATH" "${BAK_DATE}-database"
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
         $ECHO_BIN " CMD : '$TAR_BIN' : source=$source, depth=$depth, inc=$inc'" >> $BAK_OUTPUT_EXTENDED
         $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
         file="$BAK_CONFIG_SERVER_PATH/${BAK_DATE}-${name}-backup.tar.bz2"
         if [ $BAK_DEBUG -eq 1 ]; then
            $ECHO_BIN -n "$TAR_BIN $TAR_OPTS '$file' '$source' ... " >> $BAK_OUTPUT
         else
            $TAR_BIN $TAR_OPTS "$file" "$source" >> $BAK_OUTPUT_EXTENDED 2>&1
         fi
         config_error=$?
         if [ $config_error -eq 0 ];then
            $ECHO_BIN -n "OK" >> $BAK_OUTPUT
            size=`file_size $file`
            $ECHO_BIN " ($size)" >> $BAK_OUTPUT
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
      depth=${BAK_SOURCES_CONFIG_DEPTH[$index]}
      inc=${BAK_SOURCES_CONFIG_INC[$index]}
      target="$BAK_TEMP_PATH"
      $ECHO_BIN "   '$source' (depth=$depth, inc=$inc):" >> $BAK_OUTPUT
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED
      current_date=`$DATE_BIN`
      $ECHO_BIN " START $current_date" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " ACTION Data ($index) : $source " >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " CMD : '$TAR_BIN' : source=$source, depth=$depth, inc=$inc'" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN "-------------------------------------------------------------" >> $BAK_OUTPUT_EXTENDED

      # Check depth
      if [ $depth -gt 0 ]; then
         find "$source" -maxdepth $depth -mindepth $depth -type d -not -name ".*" | while read dir
         do
            source_backup "$dir" "$target" $inc
            item_error=$?
            if [ $item_error -ne 0 ]; then
               $ECHO_BIN "   ERROR: Source '$source' stop with error = $item_error" >> $BAK_OUTPUT
               error=1;
               break;
            fi
         done
      else
         source_backup "$source" "$target" $inc
         item_error=$?
         if [ $item_error -ne 0 ]; then
            $ECHO_BIN "   ERROR: Source '$source' stop with error = $item_error" >> $BAK_OUTPUT
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
      size=`dir_size $dir`
      $ECHO_BIN " ($size) ... " >> $BAK_OUTPUT

      if [ $inc -eq 1 ]; then
         extra="-g $local_incfile"
      fi

      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$TAR_BIN $extra $TAR_OPTS '$tarfile' '$dir' ... " >> $BAK_OUTPUT
      else
         $TAR_BIN $extra $TAR_OPTS "$tarfile" "$dir" >> $BAK_OUTPUT_EXTENDED 2>&1
      fi
      source_error=$?

      if [ $source_error -eq 0 ] && [ $inc -eq 1 ]; then
         # Copy inc file to target
         if [ $BAK_DEBUG -eq 1 ]; then
            source_error=0
         else
            $CP_BIN "$local_incfile" "$remote_incfile"
         fi
      fi

      if [ $source_error -eq 0 ]; then
         $ECHO_BIN -n "OK" >> $BAK_OUTPUT
         size=`file_size $tarfile`
         $ECHO_BIN " ($size)" >> $BAK_OUTPUT
      else
         $ECHO_BIN "FAIL (error = $source_error)" >> $BAK_OUTPUT
         error=1
      fi

   else
      $ECHO_BIN "ERROR : Bad parameters in 'source_backup' DIR = '$DIR', TARGET = '$TARGET', INC = '$INC'" >> $BAK_OUTPUT
      error=1
   fi

   # Process this backup
   if [ $error -eq 0 ]; then
      backup_process "$target" "${BAK_DATE}-$name"
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
      size=`dir_size "$dir"`
      $ECHO_BIN "         Process Backup '$name' ($size)" >> $BAK_OUTPUT
      # Compress $dir into output dir
      $ECHO_BIN -n "         -> Compress backup files ... " >> $BAK_OUTPUT
      tarfile="$BAK_OUTPUT_PATH/$name.tar.gz"
      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$COMPRESS_BIN '$tarfile' '$dir' ... " >> $BAK_OUTPUT
      else
         $COMPRESS_BIN "$tarfile" "$dir"  > $BAK_NULL_OUTPUT 2>&1
      fi
      error=$?
      if [ $error -eq 0 ]; then
         $ECHO_BIN -n "OK" >> $BAK_OUTPUT
         size=`file_size $tarfile`
         $ECHO_BIN " ($size)" >> $BAK_OUTPUT
      else
         $ECHO_BIN "FAIL (error = $error)" >> $BAK_OUTPUT;
      fi

      file_to_upload="$tarfile"

      # Delete all files in $dir
      $ECHO_BIN -n "         -> Delete backup files ... " >> $BAK_OUTPUT
      if [ $BAK_DEBUG -eq 1 ]; then
         $ECHO_BIN -n "$RM_BIN '$dir'/* ... " >> $BAK_OUTPUT
      else
         $RM_BIN "$dir"/*
      fi
      $ECHO_BIN "OK" >> $BAK_OUTPUT

      if [ $error -eq 0 ]; then
         # Encrypt backup
         $ECHO_BIN -n "         -> Encrypt backup ... " >> $BAK_OUTPUT
         encfile="$BAK_OUTPUT_PATH/$name.tar.gz.enc"
         if [ $BAK_DEBUG -eq 1 ]; then
            $ECHO_BIN -n "$OPENSSL_ENC_BIN -in '$tarfile' -out '$encfile' ... " >> $BAK_OUTPUT
         else
            $OPENSSL_ENC_BIN -in "$tarfile" -out "$encfile"
         fi
         error=$?
         if [ $error -eq 0 ]; then
            $ECHO_BIN -n "OK" >> $BAK_OUTPUT
            size=`file_size $encfile`
            $ECHO_BIN " ($size)" >> $BAK_OUTPUT
            if [ $BAK_DEBUG -eq 0 ]; then
               $RM_BIN "$tarfile"
            fi
            file_to_upload="$encfile"
         else $ECHO_BIN "FAIL (error = $error)" >> $BAK_OUTPUT; fi
      fi

      if [ $error -eq 0 ]; then
         # Copy to each remote backend
         $ECHO_BIN -n "         -> Copy to backends ..." >> $BAK_OUTPUT
         for be in $BAK_REMOTE_BACKENDS; do
            $ECHO_BIN -n " $be " >> $BAK_OUTPUT
            bef="${be}_put"
            if [ $BAK_DEBUG -eq 1 ]; then
               $ECHO_BIN  -n "$bef '$file_to_upload' " >> $BAK_OUTPUT
            else
               $bef "$file_to_upload"
            fi
            be_error=$?
            if [ $be_error -eq 0 ]; then
               $ECHO_BIN -n "[OK]" >> $BAK_OUTPUT
            else
               $ECHO_BIN -n "[ERROR = $be_error]" >> $BAK_OUTPUT
            fi
         done
         $ECHO_BIN >> $BAK_OUTPUT

         # Move to local backend or delete
         if [ "$BAK_LOCAL_BACKENDS" == "local" ]; then
            $ECHO_BIN -n "         -> Move to local backend ... " >> $BAK_OUTPUT
            if [ $BAK_DEBUG -eq 1 ]; then
               $ECHO_BIN -n "$MV_BIN '$file_to_upload' '$BAK_LOCAL_PATH' ... " >> $BAK_OUTPUT
            else
               $MV_BIN "$file_to_upload" "$BAK_LOCAL_PATH"
            fi
         else
            $ECHO_BIN -n "         -> Delete backup ... " >> $BAK_OUTPUT
            if [ $BAK_DEBUG -eq 1 ]; then
               $ECHO_BIN -n "$RM_BIN '$file_to_upload' ... " >> $BAK_OUTPUT
            else
               $RM_BIN "$file_to_upload"
            fi
         fi
         $ECHO_BIN "OK" >> $BAK_OUTPUT
      fi
   else
      $ECHO_BIN "ERROR : Bad parameters in 'backup_process' DIR = '$DIR', NAME = '$NAME'" >> $BAK_OUTPUT
   fi
}

##################################################################
# source_config_read
#  Read sources configuration
##################################################################
source_config_read(){
    local i=0
    local line=

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
   $ECHO_BIN "Content-Type: text/plain; charset=ISO-8859-1" >> $BAK_MAIL_TEMP_FILE
   $ECHO_BIN "Content-Transfer-Encoding: 8bit" >> $BAK_MAIL_TEMP_FILE
   $ECHO_BIN >> $BAK_MAIL_TEMP_FILE
   $CAT_BIN $BAK_OUTPUT >> $BAK_MAIL_TEMP_FILE
   if [ $1 -eq 1 ]; then
      $CAT_BIN $BAK_MAIL_TEMP_FILE | $SENDMAIL_BIN -f $BAK_MAIL_FROM_USER -t $BAK_MAIL_TO
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
   $ECHO_BIN -n "BACKUP START - " >> $BAK_OUTPUT;
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
   $ECHO_BIN -n "BACKUP END   - " >> $BAK_OUTPUT;
   $ECHO_BIN $BAK_END_DATE >> $BAK_OUTPUT;
   $ECHO_BIN "----------------------------------------------------------------" >> $BAK_OUTPUT;
}

##################################################################
# directories_create
#  Create directories (if needed)
##################################################################
directories_create() {
   # Create log directory (if needed)
   if [ ! -d "$BAK_LOG_PATH" ]; then
      $ECHO_BIN "INFO : Creating log dir '$BAK_LOG_PATH'"
      $MKDIR_BIN "$BAK_LOG_PATH"
   fi

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

   # Create database directory (if needed)
   if [ ! -d "$BAK_DATABASE_PATH" ]; then
      $ECHO_BIN "INFO : Creating database dir '$BAK_DATABASE_PATH'"
      $MKDIR_BIN "$BAK_DATABASE_PATH"
   fi

   # Create server config directory (if needed)
   if [ ! -d "$BAK_CONFIG_SERVER_PATH" ]; then
      $ECHO_BIN "INFO : Creating server config dir '$BAK_CONFIG_SERVER_PATH'"
      $MKDIR_BIN "$BAK_CONFIG_SERVER_PATH"
   fi

   if [ -n "$BAK_LOCAL_PATH" ] && [ ! -d "$BAK_LOCAL_PATH" ]; then
      $ECHO_BIN "INFO : Creating local backend dir '$BAK_LOCAL_PATH'"
      $MKDIR_BIN "$BAK_LOCAL_PATH"
      $SR_BIN "$BAK_LOCAL_PATH"
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

environment_check() {
   local index=0
   local file=

   for index in `seq 0 1 $((${#BAK_ENVIRONMENT_LIST[@]} - 1))`; do
      file="${BAK_ENVIRONMENT_LIST[$index]}"
      if [ ! -x "$file" ]; then
         $ECHO_BIN "ERROR : Environment checking : '$file' not found or not executable";
         exit 1
      fi
   done
}

executable_set() {
   local file=$1

   if [ ! -f "$file" ]; then echo "ERROR : File '$file' not found. Please download again"; exit 1; fi
   if [ ! -x "$file" ]; then echo "INFO : Setting '$file' executable"; chmod +x "$file"; fi;
}

