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

BAK_FOLDER_CMD_BIN='/bin/cp'
BAK_FOLDER_GET_BIN="$BAK_FOLDER_CMD_BIN -a"
BAK_FOLDER_PUT_BIN="$BAK_FOLDER_CMD_BIN -a"

BAK_FOLDER_CURRENT_PATH=
BAK_FOLDER_ERROR=0

folder_check() {
   if [ ! $BAK_FOLDER_ERROR -eq 0 ]; then return $BAK_FOLDER_ERROR; fi
   return 0
}

folder_config_show() {
   if [ $BAK_FOLDER_ERROR -eq 0 ]; then status="OK";
   else status="ERROR ($BAK_FOLDER_ERROR)"; error=$BAK_FOLDER_ERROR; fi

   cat << CONFIG
Folder Configuration
------------------------------------------------
Current file : $BAK_FOLDER_CURRENT_FILE - $BAK_FOLDER_CURRENT_PATH
Path         : $BAK_FOLDER_PATH
Status       : $status

CONFIG
}

folder_snapshot() {
   local cfile="/tmp/$BAK_FOLDER_CURRENT_FILE"
   local error=0
   local date=`$DATE_BIN +%F`

   if [ ! $BAK_FOLDER_ERROR -eq 0 ]; then return $BAK_FOLDER_ERROR; fi

   $ECHO_BIN "$date" > "$cfile"
   $ECHO_BIN "Folder : Setting new current file : '$date'" >> $BAK_OUTPUT
   $BAK_FOLDER_PUT_BIN "$cfile" "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_FILE" > $BAK_NULL_OUTPUT 2>&1
   error=$?

   if [ $error -eq 0 ]; then
      BAK_FOLDER_CURRENT_PATH="$date"
   fi

   $RM_BIN "$cfile"

   return $error
}

folder_environment_check() {
   # Do nothig
   return 0
}

folder_mount() {
   local error=0
   local date=
   local cfile="/tmp/$BAK_FOLDER_CURRENT_FILE"

   if [ ! $BAK_FOLDER_ERROR -eq 0 ]; then return $BAK_FOLDER_ERROR; fi

   if [ ! -d "$BAK_FOLDER_PATH" ]; then
      $ECHO_BIN "INFO : Creating folder dir '$BAK_FOLDER_PATH'"
      $MKDIR_BIN "$BAK_FOLDER_PATH"
   fi

   $BAK_FOLDER_GET_BIN "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_FILE" "$cfile" > $BAK_NULL_OUTPUT 2>&1
   error=$?

   if [ $error -eq 0 ]; then
      # current file exists, use it
      BAK_FOLDER_CURRENT_PATH=`cat "$cfile"`
   else
      # current file does not exists, create it
      date=`$DATE_BIN +%F`
      $ECHO_BIN "$date" > "$cfile"
      $BAK_FOLDER_PUT_BIN "$cfile" "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_FILE" > $BAK_NULL_OUTPUT 2>&1
      error=$?

      if [ $error -eq 0 ]; then
         BAK_FOLDER_CURRENT_PATH="$date"
      else
         BAK_FOLDER_ERROR=$error
      fi
   fi

   $RM_BIN "$cfile"
}

folder_umount() {
   return 0
}

folder_init() {
   folder_check
   BAK_FOLDER_ERROR=$?
}

folder_get() {
   local error=0
   local file=$1
   local name=`basename $file`

   if [ ! $BAK_FOLDER_ERROR -eq 0 ]; then return $BAK_FOLDER_ERROR; fi

   if [ -f "$file" ]; then
      $ECHO_BIN " CMD : $BAK_FOLDER_GET_BIN '$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH/$name' '$file'" >> $BAK_OUTPUT_EXTENDED
      $BAK_FOLDER_GET_BIN "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH/$name" "$file" >> $BAK_OUTPUT_EXTENDED 2>&1
      error=$?
   else
      error=1
   fi
   return $error
}

folder_put() {
   local error=0
   local file=$1
   local name=`basename $file`

   if [ ! $BAK_FOLDER_ERROR -eq 0 ]; then return $BAK_FOLDER_ERROR; fi

   if [ ! -d "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH" ]; then
      $ECHO_BIN "INFO : Creating folder dir '$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH'"
      $MKDIR_BIN "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH"
   fi

   if [ -f "$file" ]; then
      $ECHO_BIN " CMD : $BAK_FOLDER_PUT_BIN '$file' '$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH/$name'" >> $BAK_OUTPUT_EXTENDED
      $BAK_FOLDER_PUT_BIN "$file" "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH/$name" >> $BAK_OUTPUT_EXTENDED 2>&1
      error=$?
   else
      error=1
   fi
   return $error
}

folder_init

