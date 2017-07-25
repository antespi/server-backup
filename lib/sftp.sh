#!/bin/bash
# Server-Backup  Copyright (C) 2017
#                Antonio Espinosa <antonio.espinosa@ontruck.com>
#
# This file is part of Server-Backup by Antonio Espinosa (@antespi)
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

BAK_SFTP_TIMEOUT=3
BAK_SFTP_BASE="$BAK_SFTP_INSTANCE"
BAK_SFTP_CMD_BIN='/usr/bin/sftp'
BAK_SFTP_CONFIG_FILE="$BAK_CONFIG_PATH/.sftpcfg"
BAK_SFTP_BIN="$BAK_SFTP_CMD_BIN -F $BAK_SFTP_CONFIG_FILE -b -"

BAK_SFTP_CURRENT_PATH=
BAK_SFTP_ERROR=0

sftp_check() {
   local host=$1
   local ctx=$2
   local output=$BAK_OUTPUT_EXTENDED

   if [ ! $BAK_SFTP_ERROR -eq 0 ]; then return $BAK_SFTP_ERROR; fi

   if [ "$ctx" == "init" ]; then
      output=$BAK_NULL_OUTPUT
   fi

   $ECHO_BIN "SFTP Check '$host'" >> $output
   $ECHO_BIN " CMD : $BAK_SFTP_BIN" >> $output
   $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL >> $output 2>&1
ls
quit
EOL
   return $?
}

sftp_config_show() {
   local error=0
   local status=
   local sftp_status=
   local sftpcmd_status=

   if [ $BAK_SFTP_ERROR -eq 0 ]; then status="OK";
   else status="ERROR ($BAK_SFTP_ERROR)"; error=$BAK_SFTP_ERROR; fi

   if [ -f "$BAK_SFTP_CMD_BIN" ]; then
      sftpcmd_status="OK"
   else
      sftpcmd_status="ERROR : SFTP is not installed"
   fi

   if [ -f "$BAK_SFTP_CONFIG_FILE" ]; then
      for host in $BAK_SFTP_HOSTS; do
         if sftp_check $host; then
            sftp_status="OK"
         else
            error=$?
            sftp_status=`sftp_errmsg $error on host $host`
            break
         fi
      done
   else
      sftp_status="ERROR : File not found"
      error=1
   fi

   cat << CONFIG
SFTP Configuration
------------------------------------------------
SFTP         : $BAK_SFTP_CMD_BIN - $sftpcmd_status
Current file : $BAK_SFTP_CURRENT_FILE - $BAK_SFTP_CURRENT_PATH
SFTP config  : $BAK_SFTP_CONFIG_FILE - $sftp_status
SFTP user    : $BAK_SFTP_USER
Path         : [$BAK_SFTP_HOSTS]/$BAK_SFTP_INSTANCE
Status       : $status

CONFIG

   return $error
}

sftp_errmsg() {
   local error=$1

   $ECHO_BIN "ERROR($error) : Error in SFTP configuration"
}

sftp_snapshot() {
   local cfile="/tmp/$BAK_SFTP_CURRENT_FILE"
   local error=0
   local date=`$DATE_BIN +%F`

   if [ ! $BAK_SFTP_ERROR -eq 0 ]; then return $BAK_SFTP_ERROR; fi

   $ECHO_BIN "$date" > "$cfile"
   $ECHO_BIN "SFTP : Setting new current file : '$date'" >> $BAK_OUTPUT
   $ECHO_BIN "SFTP SNAPSHOT : '$BAK_SFTP_BASE/' <- '$cfile' ($date)" >> $BAK_OUTPUT_EXTENDED
   $ECHO_BIN " CMD : $BAK_SFTP_BIN '$cfile'" >> $BAK_OUTPUT_EXTENDED
   for host in $BAK_SFTP_HOSTS; do
       $ECHO_BIN "SFTP : Connecting to '$host'" >> $BAK_OUTPUT_EXTENDED
       $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL >> $BAK_OUTPUT_EXTENDED 2>&1
cd "$BAK_SFTP_BASE"
put "$cfile"
quit
EOL
   done
   error=$?

   # TODO : Define in configuration file how many folders to hold
   # TODO : Remove old folders with pattern "xxxx-xx-xx"

   if [ $error -eq 0 ]; then
      BAK_SFTP_CURRENT_PATH="$date"
   fi

   $RM_BIN "$cfile"

   return $error
}

sftp_environment_check() {
   if [ ! $BAK_SFTP_ERROR -eq 0 ]; then
      sftp_errmsg $BAK_SFTP_ERROR
      return $BAK_SFTP_ERROR;
   fi
   if [ ! -f "$BAK_SFTP_CMD_BIN" ]; then
      $ECHO_BIN "ERROR : SFTP is not installed"
      return 1;
   fi
   return 0
}

sftp_mount() {
   return 0
}

sftp_umount() {
   return 0
}

sftp_init() {
   local error=0
   local date=`$DATE_BIN +%F`
   local cfile="/tmp/$BAK_SFTP_CURRENT_FILE"

   if [ -f "$BAK_SFTP_CONFIG_FILE" ]; then
      $CHMOD_BIN 640 "$BAK_SFTP_CONFIG_FILE"
      # $CHOWN_BIN $BAK_SFTP_LOCAL_USER:$BAK_SFTP_LOCAL_GROUP "$BAK_SFTP_CONFIG_FILE"

      for host in $BAK_SFTP_HOSTS; do
         sftp_check $host 'init'
         BAK_SFTP_ERROR=$?
         if [ $BAK_SFTP_ERROR -ne 0 ]; then break; fi
      done

      if [ $BAK_SFTP_ERROR -eq 0 ]; then
         for host in $BAK_SFTP_HOSTS; do
            $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL > $BAK_NULL_OUTPUT 2>&1
cd "$BAK_SFTP_BASE"
lcd "/tmp"
get "$BAK_SFTP_CURRENT_FILE"
quit
EOL
            error=$?

            if [ $error -eq 0 ]; then
               # current file exists, use it
               BAK_SFTP_CURRENT_PATH=`cat "$cfile"`
            else
               BAK_SFTP_CURRENT_PATH="$date"
               # current file does not exists, create it
               $ECHO_BIN "$date" > "$cfile"
               $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL > $BAK_NULL_OUTPUT 2>&1
cd "$BAK_SFTP_BASE"
quit
EOL
               error=$?
               if [ $error -ne 0 ]; then
                  $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL > $BAK_NULL_OUTPUT 2>&1
mkdir "$BAK_SFTP_BASE"
quit
EOL
                  error=$?
                  if [ $error -ne 0 ]; then break; fi
               fi
               $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL > $BAK_NULL_OUTPUT 2>&1
cd "$BAK_SFTP_BASE"
put "$cfile"
quit
EOL
               error=$?
               if [ $error -ne 0 ]; then break; fi
            fi
            if [ $error -eq 0 ]; then
               $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL > $BAK_NULL_OUTPUT 2>&1
cd "$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH"
quit
EOL
               error=$?
               if [ $error -ne 0 ]; then
                  $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL > $BAK_NULL_OUTPUT 2>&1
mkdir "$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH"
quit
EOL
                  error=$?
                  if [ $error -ne 0 ]; then break; fi
               fi
            fi
         done

         if [ $error -ne 0 ]; then
            BAK_SFTP_ERROR=$error
         fi

         $RM_BIN "$cfile"
      fi
   else
      BAK_SFTP_ERROR=1
   fi
}

sftp_get() {
   local error=0
   local file=$1
   local localpath=`dirname $file`
   local name=`basename $file`

   if [ ! $BAK_SFTP_ERROR -eq 0 ]; then return $BAK_SFTP_ERROR; fi

   $ECHO_BIN "SFTP GET : '$localpath' <- '$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH/$name'" >> $BAK_OUTPUT_EXTENDED
   if [ -f "$file" ]; then
      $ECHO_BIN " CMD : $BAK_SFTP_BIN '$localpath' '$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH/$name'" >> $BAK_OUTPUT_EXTENDED
      for host in $BAK_SFTP_HOSTS; do
         $ECHO_BIN "SFTP : Connecting to '$host'" >> $BAK_OUTPUT_EXTENDED
         $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL >> $BAK_OUTPUT_EXTENDED 2>&1
lcd "$localpath"
cd "$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH"
get "$name"
quit
EOL
      done
      error=$?
   else
      $ECHO_BIN " ERROR: File '$file' not found" >> $BAK_OUTPUT_EXTENDED
      error=1
   fi
   return $error
}

sftp_put() {
   local error=0
   local file=$1
   local name=`basename $file`

   if [ ! $BAK_SFTP_ERROR -eq 0 ]; then return $BAK_SFTP_ERROR; fi

   $ECHO_BIN "SFTP PUT : '$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH/' <- '$file'" >> $BAK_OUTPUT_EXTENDED
   if [ -f "$file" ]; then
      $ECHO_BIN " CMD : $BAK_SFTP_BIN '$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH/' '$file'" >> $BAK_OUTPUT_EXTENDED
      for host in $BAK_SFTP_HOSTS; do
         $ECHO_BIN "SFTP : Connecting to '$host'" >> $BAK_OUTPUT_EXTENDED
         $BAK_SFTP_BIN ${BAK_SFTP_USER}@${host} << EOL >> $BAK_OUTPUT_EXTENDED 2>&1
cd "$BAK_SFTP_BASE/$BAK_SFTP_CURRENT_PATH"
put "$file"
quit
EOL
      done
      error=$?
   else
      $ECHO_BIN " ERROR: File '$file' not found" >> $BAK_OUTPUT_EXTENDED
      error=1
   fi
   return $error
}

sftp_init
