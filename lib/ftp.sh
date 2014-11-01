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

# Not tested !!!!

BAK_FTP_TIMEOUT=3
BAK_FTP_CMD_BIN='/usr/bin/ncftp'
BAK_FTP_CONFIG_FILE="$BAK_CONFIG_PATH/.ftpcfg"
BAK_FTP_CHECK_BIN="/usr/bin/ncftpls -f $BAK_FTP_CONFIG_FILE -t $BAK_FTP_TIMEOUT -r 1"
BAK_FTP_GET_BIN="/usr/bin/ncftpget -f $BAK_FTP_CONFIG_FILE -t $BAK_FTP_TIMEOUT -Z -r 1"
BAK_FTP_PUT_BIN="/usr/bin/ncftpput -f $BAK_FTP_CONFIG_FILE -t $BAK_FTP_TIMEOUT -Z -r 1"
BAK_FTP_BASE=''

BAK_FTP_CURRENT_PATH=
BAK_FTP_ERROR=0

ftp_check() {
   local host=`cat $BAK_FTP_CONFIG_FILE | grep host | cut -d' ' -f2`
   local user=`cat $BAK_FTP_CONFIG_FILE | grep user | cut -d' ' -f2`
   local pass=`cat $BAK_FTP_CONFIG_FILE | grep pass | cut -d' ' -f2`

   if [ ! $BAK_FTP_ERROR -eq 0 ]; then return $BAK_FTP_ERROR; fi

   $BAK_FTP_CHECK_BIN -x "quit" ftp://$host > $BAK_NULL_OUTPUT 2>&1
   return $?
}

ftp_config_show() {
   local error=0
   local status=
   local ftp_status=
   local ftpcmd_status=
   local host='unset'

   if [ $BAK_FTP_ERROR -eq 0 ]; then status="OK";
   else status="ERROR ($BAK_FTP_ERROR)"; error=$BAK_FTP_ERROR; fi

   if [ -f "$BAK_FTP_CMD_BIN" ]; then
      ftpcmd_status="OK"
   else
      ftpcmd_status="ERROR : NcFTP is not installed"
   fi

   if [ -f "$BAK_FTP_CONFIG_FILE" ]; then
      host=`cat $BAK_FTP_CONFIG_FILE | grep host | cut -d' ' -f2`
      if ftp_check; then
         ftp_status="OK"
      else
         error=$?
         ftp_status=`ftp_errmsg $error`
      fi
   else
      ftp_status="ERROR : File not found"
      error=1
   fi

   cat << CONFIG
FTP Configuration
------------------------------------------------
NcFTP        : $BAK_FTP_CMD_BIN - $ftpcmd_status
Current file : $BAK_FTP_CURRENT_FILE - $BAK_FTP_CURRENT_PATH
FTP config   : $BAK_FTP_CONFIG_FILE - $ftp_status
Path         : [$host]/$BAK_FTP_INSTANCE
Status       : $status

CONFIG

   return $error
}

ftp_errmsg() {
   local error=$1

   if [ $error -eq 1 ] || [ $error -eq 2 ]; then $ECHO_BIN "ERROR($error) : Invalid FTP configuration, could not connect to host";
   elif [ $error -eq 9 ]; then $ECHO_BIN "ERROR($error) : Invalid FTP configuration, login failed";
   else $ECHO_BIN "ERROR($error) : Invalid FTP configuration"; fi
}

ftp_snapshot() {
   local cfile="/tmp/$BAK_FTP_CURRENT_FILE"
   local error=0
   local date=`$DATE_BIN +%F`

   if [ ! $BAK_FTP_ERROR -eq 0 ]; then return $BAK_FTP_ERROR; fi

   $ECHO_BIN "$date" > "$cfile"
   $ECHO_BIN "FTP : Setting new current file : '$date'" >> $BAK_OUTPUT
   $BAK_FTP_PUT_BIN "$BAK_FTP_BASE/" "$cfile"  > $BAK_NULL_OUTPUT 2>&1
   error=$?

   # TODO : Define in configuration file how many folders to hold
   # TODO : Remove old folders with pattern "xxxx-xx-xx"

   if [ $error -eq 0 ]; then
      BAK_FTP_CURRENT_PATH="$date"
   fi

   $RM_BIN "$cfile"

   return $error
}

ftp_environment_check() {
   if [ ! $BAK_FTP_ERROR -eq 0 ]; then
      ftp_errmsg $BAK_FTP_ERROR
      return $BAK_FTP_ERROR;
   fi
   if [ ! -f "$BAK_FTP_CMD_BIN" ]; then
      $ECHO_BIN "ERROR : NcFTP is not installed"
      return 1;
   fi
   return 0
}

ftp_mount() {
   return 0
}

ftp_umount() {
   return 0
}

ftp_init() {
   local error=0
   local date=
   local cfile="/tmp/$BAK_FTP_CURRENT_FILE"

   if [ -f "$BAK_FTP_CONFIG_FILE" ]; then
      $CHMOD_BIN 640 "$BAK_FTP_CONFIG_FILE"
      $CHOWN_BIN root:root "$BAK_FTP_CONFIG_FILE"

      ftp_check
      BAK_FTP_ERROR=$?

      if [ $BAK_FTP_ERROR -eq 0 ]; then
         $BAK_FTP_GET_BIN "/tmp" "$BAK_FTP_BASE/$BAK_FTP_CURRENT_FILE"  > $BAK_NULL_OUTPUT 2>&1
         error=$?

         if [ $error -eq 0 ]; then
            # current file exists, use it
            BAK_FTP_CURRENT_PATH=`cat "$cfile"`
         else
            # current file does not exists, create it
            date=`$DATE_BIN +%F`
            $ECHO_BIN "$date" > "$cfile"
            $BAK_FTP_PUT_BIN "$BAK_FTP_BASE/" "$cfile"  > $BAK_NULL_OUTPUT 2>&1
            error=$?

            if [ $error -eq 0 ]; then
               BAK_FTP_CURRENT_PATH="$date"
            else
               BAK_FTP_ERROR=$error
            fi
         fi

         $RM_BIN "$cfile"
      fi
   else
      BAK_FTP_ERROR=1
   fi
}

ftp_get() {
   local error=0
   local file=$1
   local localpath=`dirname $file`
   local name=`basename $file`

   if [ ! $BAK_FTP_ERROR -eq 0 ]; then return $BAK_FTP_ERROR; fi

   if [ -f "$file" ]; then
      $ECHO_BIN "FTP GET : '$localpath' <- '$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/$name'" >> $BAK_OUTPUT_EXTENDED
      $BAK_FTP_GET_BIN "$localpath" "$BAK_FTP_BASE/$BAK_FTP_CURRENT_PATH/$name" > $BAK_NULL_OUTPUT 2>> $BAK_OUTPUT_EXTENDED
      error=$?
   else
      error=1
   fi
   return $error
}

ftp_put() {
   local error=0
   local file=$1
   local name=`basename $file`

   if [ ! $BAK_FTP_ERROR -eq 0 ]; then return $BAK_FTP_ERROR; fi

   if [ -f "$file" ]; then
      $ECHO_BIN "FTP PUT : '$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/' <- '$file'" >> $BAK_OUTPUT_EXTENDED
      $BAK_FTP_PUT_BIN "$BAK_FTP_BASE/$BAK_FTP_CURRENT_PATH/" "$file" > $BAK_NULL_OUTPUT 2>> $BAK_OUTPUT_EXTENDED
      error=$?
   else
      error=1
   fi
   return $error
}

ftp_init
