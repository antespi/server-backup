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

BAK_S3_CMD_BIN='/usr/bin/s3cmd'
BAK_S3_MD5_BIN='/usr/bin/s3md5'
BAK_S3_CONFIG_FILE="$BAK_CONFIG_PATH/.s3cfg"
BAK_S3_GET_BIN="$BAK_S3_CMD_BIN -c $BAK_S3_CONFIG_FILE --no-progress get"
BAK_S3_PUT_BIN="$BAK_S3_CMD_BIN -c $BAK_S3_CONFIG_FILE --no-progress put"
BAK_S3_MV_BIN="$BAK_S3_CMD_BIN -c $BAK_S3_CONFIG_FILE mv"
BAK_S3_EXISTS_BIN="$BAK_S3_CMD_BIN -c $BAK_S3_CONFIG_FILE info"
BAK_S3_AUTOCHECK_BIN="$BAK_S3_CMD_BIN -c $BAK_S3_CONFIG_FILE info"

BAK_S3_BASE="s3://$BAK_S3_BUCKET/$BAK_S3_INSTANCE"

BAK_S3_CURRENT_PATH=
BAK_S3_ERROR=0

s3_check() {
   if [ ! $BAK_S3_ERROR -eq 0 ]; then return $BAK_S3_ERROR; fi

   if $BAK_S3_AUTOCHECK_BIN "s3://$BAK_S3_BUCKET" 2>&1 | grep -q "ERROR"; then
      return 1
   fi
   return $?
}

s3_config_show() {
   local error=0
   local status=
   local aws_status=
   local s3cmd_status=
   local s3md5_status=

   if [ $BAK_S3_ERROR -eq 0 ]; then status="OK";
   else status="ERROR ($BAK_S3_ERROR)"; error=$BAK_S3_ERROR; fi

   if [ -f "$BAK_S3_CMD_BIN" ]; then
      s3cmd_status="OK"
   else
      s3cmd_status="ERROR : S3cmd is not installed"
   fi

   if [ -f "$BAK_S3_MD5_BIN" ]; then
      s3md5_status="OK"
   else
      s3md5_status="ERROR : S3md5 is not installed"
   fi

   if [ -f "$BAK_S3_CONFIG_FILE" ]; then
      if s3_check; then
         aws_status="OK"
      else
         aws_status="ERROR : Invalid configuration, please set your credentials"
         error=1
      fi
   else
      aws_status="ERROR : File not found"
      error=1
   fi

   cat << CONFIG
S3 Configuration
------------------------------------------------
S3cmd        : $BAK_S3_CMD_BIN - $s3cmd_status
S3md5        : $BAK_S3_MD5_BIN - $s3md5_status
Current file : $BAK_S3_CURRENT_FILE - $BAK_S3_CURRENT_PATH
AWS config   : $BAK_S3_CONFIG_FILE - $aws_status
Path         : [$BAK_S3_BUCKET]/$BAK_S3_INSTANCE
Status       : $status

CONFIG

   return $error
}

s3_snapshot() {
   local cfile="/tmp/$BAK_S3_CURRENT_FILE"
   local error=0
   local date=`$DATE_BIN +%F`

   if [ ! $BAK_S3_ERROR -eq 0 ]; then return $BAK_S3_ERROR; fi

   $ECHO_BIN "$date" > "$cfile"
   $ECHO_BIN "S3 : Setting new current file : '$date'" >> $BAK_OUTPUT
   $BAK_S3_PUT_BIN "$cfile" "$BAK_S3_BASE/$BAK_S3_CURRENT_FILE" > $BAK_NULL_OUTPUT 2>&1
   error=$?

   if [ $error -eq 0 ]; then
      BAK_S3_CURRENT_PATH="$date"
   fi

   $RM_BIN "$cfile"

   return $error
}

s3_environment_check() {
   if [ ! $BAK_S3_ERROR -eq 0 ]; then
      $ECHO_BIN "ERROR : Invalid S3 configuration, please set your credentials"
      return $BAK_S3_ERROR;
   fi
   if [ ! -f "$BAK_S3_CMD_BIN" ]; then
      $ECHO_BIN "ERROR : S3cmd is not installed"
      return 1;
   fi
   return 0
}

s3_mount() {
   return 0
}

s3_umount() {
   return 0
}

s3_init() {
   local error=0
   local date=
   local cfile="/tmp/$BAK_S3_CURRENT_FILE"

   if [ -f "$BAK_S3_CONFIG_FILE" ]; then
      $CHMOD_BIN 640 "$BAK_S3_CONFIG_FILE"
      $CHOWN_BIN root:root "$BAK_S3_CONFIG_FILE"

      s3_check
      BAK_S3_ERROR=$?

      if [ $BAK_S3_ERROR -eq 0 ]; then
         $BAK_S3_GET_BIN "$BAK_S3_BASE/$BAK_S3_CURRENT_FILE" "$cfile" > $BAK_NULL_OUTPUT 2>&1
         error=$?

         if [ $error -eq 0 ]; then
            # current file exists, use it
            BAK_S3_CURRENT_PATH=`cat "$cfile"`
         else
            # current file does not exists, create it
            date=`$DATE_BIN +%F`
            $ECHO_BIN "$date" > "$cfile"
            $BAK_S3_PUT_BIN "$cfile" "$BAK_S3_BASE/$BAK_S3_CURRENT_FILE" > $BAK_NULL_OUTPUT 2>&1
            error=$?

            if [ $error -eq 0 ]; then
               BAK_S3_CURRENT_PATH="$date"
            else
               BAK_S3_ERROR=$error
            fi
         fi

         $RM_BIN "$cfile"
      fi
   else
      BAK_S3_ERROR=1
   fi
}

s3_get() {
   local error=0
   local file=$1
   local name=`basename $file`

   if [ ! $BAK_S3_ERROR -eq 0 ]; then return $BAK_S3_ERROR; fi

   if [ -f "$file" ]; then
      $ECHO_BIN " CMD : $BAK_S3_GET_BIN '$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/$name' '$file'" >> $BAK_OUTPUT_EXTENDED
      $BAK_S3_GET_BIN "$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/$name" "$file" >> $BAK_OUTPUT_EXTENDED 2>&1
      error=$?
   else
      error=1
   fi
   return $error
}

s3_put() {
   local error=0
   local file=$1
   local name=`basename $file`
   local infofile="/tmp/$name_$$.info"
   local localmd5=
   local s3md5=
   local chunk_size=`$GREP_BIN "multipart_chunk_size_mb" "$BAK_S3_CONFIG_FILE" | $SED_BIN 's/ *//g' | $CUT_BIN -d'=' -f2`

   if [ ! $BAK_S3_ERROR -eq 0 ]; then return $BAK_S3_ERROR; fi

   if [ -f "$file" ]; then
      $ECHO_BIN " CMD : $BAK_S3_PUT_BIN '$file' '$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/$name'" >> $BAK_OUTPUT_EXTENDED
      $BAK_S3_PUT_BIN "$file" "$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/$name"  >> $BAK_OUTPUT_EXTENDED 2>&1
      error=$?
   else
      error=1
   fi

   # Get file info from S3
   if [ $error -eq 0 ]; then
      $ECHO_BIN " CMD : $BAK_S3_EXISTS_BIN '$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/$name' > $infofile" >> $BAK_OUTPUT_EXTENDED
      $BAK_S3_EXISTS_BIN "$BAK_S3_BASE/$BAK_S3_CURRENT_PATH/$name" > "$infofile" 2>&1
      error=$?
   fi

   # Compare local Etag/MD5sum vs S3 MD5sum
   if [ $error -eq 0 ]; then
      s3md5=`$CAT_BIN "$infofile" | $GREP_BIN "MD5 sum" | $SED_BIN 's/ *//g' | $CUT_BIN -d':' -f2`
      localmd5=`$MD5SUM_BIN "$file" | $CUT_BIN -d' ' -f1`
      localetag=`$BAK_S3_MD5_BIN "$chunk_size" "$file"`
      $ECHO_BIN " S3 MD5     : $s3md5" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " LOCAL MD5  : $localmd5" >> $BAK_OUTPUT_EXTENDED
      $ECHO_BIN " LOCAL ETAG : $localetag" >> $BAK_OUTPUT_EXTENDED
      if [ "$s3md5" != "$localmd5" ] && [ "$s3md5" != "$localetag" ]; then
         $ECHO_BIN " ERROR : MD5 SUM are not equal!" >> $BAK_OUTPUT_EXTENDED
         error=2
      fi
   fi

   $ECHO_BIN " CMD : $RM_BIN '$infofile'" >> $BAK_OUTPUT_EXTENDED
   $RM_BIN "$infofile" >> $BAK_OUTPUT_EXTENDED 2>&1
   return $error
}

s3_init
