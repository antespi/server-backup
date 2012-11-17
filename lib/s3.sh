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

BAK_S3_CURRENT_PATH=

s3_init() {
   local error=0
   local date=

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
      BAK_S3_CURRENT_PATH="$date"
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
