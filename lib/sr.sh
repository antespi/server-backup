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

PATH=${PWD}
USER=www-data
GROUP=www-data
CHGRP=/bin/chgrp
CHOWN=/bin/chown
FIND=/usr/bin/find
XARGS=/usr/bin/xargs
CHMOD=/bin/chmod
READLINK=/bin/readlink
PROMPT=1

if [ "$1" == "-h" -o "$1" == "--help" ]; then
   echo "Usage : $0 [-y] [path] [user] [group]"
   echo " -y : Do not prompt for confirmation (usefull for shell scripts)"
   exit 0
fi

if [ "$1" == "-y" ]; then
   PROMPT=0
   shift
fi

if [ "$1" == "." ]; then
   shift
elif [ "$1" == ".." ]; then
   PATH=`$READLINK -f $1`
   shift
elif [ -e "$1" ]; then
   PATH="$1"
   shift
fi

if [ -n "$1" ]; then
   USER="$1"
   shift
fi

if [ -n "$1" ]; then
   GROUP="$1"
   shift
fi

USER=`echo "$USER" | /bin/sed "s/^-*//g"`
GROUP=`echo "$GROUP" | /bin/sed "s/^-*//g"`

if ! /bin/egrep "^${USER}:" /etc/passwd > /dev/null; then
   echo "User '$USER' does not exists"
   exit 1;
fi

if ! /bin/grep "^${GROUP}" /etc/group > /dev/null; then
   echo "Group '$GROUP' does not exists"
   exit 1;
fi

if [ $PROMPT -eq 1 ]; then
   read -p "CONFIRM : rights ($USER:$GROUP) to $PATH [Enter to continue or Ctrl-C to abort] ..."
fi

if [ -d "$PATH" ]; then
   echo "Settings recursive rights ($USER:$GROUP) to $PATH directory"
   if ! $CHOWN -R $USER:$GROUP $PATH; then
      echo "ERROR: Can not change ownership"
      exit 1
   fi
   $FIND $PATH -type d -print0 | $XARGS -0 -r $CHMOD u+rwx,g+rwx,o-rwx
   $FIND $PATH -type f -print0 | $XARGS -0 -r $CHMOD u+rw,g+rw,o-rwx

elif [ -f "$PATH" ]; then
   echo "Settings rights ($USER:$GROUP) to $PATH file"
   if ! $CHOWN $USER:$GROUP $PATH; then
      echo "ERROR: Can not change ownership"
   exit 1
   fi
   $CHMOD u+rw,g+rw,o-rwx $PATH

else
   echo "ERROR: $PATH is not a regular file or directory"
fi
