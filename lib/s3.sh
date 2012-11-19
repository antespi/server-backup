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

BAK_S3_GET_BIN="/usr/bin/php $BAK_LIB_PATH/s3/aws-object_get.php $BAK_S3_BUCKET"
BAK_S3_PUT_BIN="/usr/bin/php $BAK_LIB_PATH/s3/aws-object_put.php $BAK_S3_BUCKET"
BAK_S3_EXISTS_BIN="/usr/bin/php $BAK_LIB_PATH/s3/aws-object_exists.php $BAK_S3_BUCKET"
BAK_S3_CONFIG_FILE="$BAK_LIB_PATH/s3/aws-php/config.inc.php"
BAK_S3_CONFIG_DIST_FILE="$BAK_LIB_PATH/s3/aws-php/config-dist.inc.php"

BAK_S3_CURRENT_PATH=
BAK_S3_ERROR=0

s3_config_show() {
   local error=0
   local status=

   if [ $BAK_S3_ERROR -eq 0 ]; then status="OK";
   else status="ERROR ($BAK_S3_ERROR)"; error=1; fi

   cat << CONFIG
S3 Configuration
------------------------------------------------
Current file : $BAK_S3_CURRENT_FILE
Path         : [$BAK_S3_BUCKET]/$BAK_S3_INSTANCE
Status       : $status

CONFIG

   return $error
}

s3_init() {
   local error=0
   local date=

   if [ ! -f "$BAK_S3_CONFIG_FILE" ]; then
      $CP_BIN "$BAK_S3_CONFIG_DIST_FILE" "$BAK_S3_CONFIG_FILE"
   fi
   $CHMOD_BIN 640 "$BAK_S3_CONFIG_FILE"
   $CHOWN_BIN root:root "$BAK_S3_CONFIG_FILE"

   $BAK_S3_GET_BIN $BAK_S3_CURRENT_FILE "/tmp/$BAK_S3_CURRENT_FILE" > $BAK_NULL_OUTPUT 2>&1
   error=$?

   if [ $error -eq 0 ]; then
      # current file exists, use it
      BAK_S3_CURRENT_PATH=`cat "/tmp/$BAK_S3_CURRENT_FILE"`
   else
      # current file does not exists, create it
      date=`date +%F`
      echo "$date" > "/tmp/$BAK_S3_CURRENT_FILE"
      $BAK_S3_PUT_BIN $BAK_S3_CURRENT_FILE "/tmp/$BAK_S3_CURRENT_FILE" > $BAK_NULL_OUTPUT 2>&1
      error=$?

      if [ $error -eq 0 ]; then
         BAK_S3_CURRENT_PATH="$date"
      else
         BAK_S3_ERROR=$error
      fi
   fi

   if [ -n "$BAK_S3_INSTANCE" ]; then
      BAK_S3_CURRENT_PATH="$BAK_S3_CURRENT_PATH/$BAK_S3_INSTANCE"
   fi
   $RM_BIN "/tmp/$BAK_S3_CURRENT_FILE"
}

s3_put() {
   error=0
   file=$1
   name=`basename $file`
   if [ -f "$file" ]; then
      $BAK_S3_PUT_BIN "$BAK_S3_CURRENT_PATH/$name" "$file" > $BAK_NULL_OUTPUT 2>&1
      error=$?
   else
      error=1
   fi
   return $error
}

s3_init
