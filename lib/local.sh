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

local_check() {
   return 0
}

local_config_show() {
   cat << CONFIG
Local Configuration
------------------------------------------------
Path         : $BAK_LOCAL_PATH
Status       : OK

CONFIG
}

local_snapshot() {
   # Do nothig
   return 0
}

local_environment_check() {
   # Do nothig
   return 0
}

local_mount() {
   # Do nothig
   return 0
}

local_umount() {
   # Do nothig
   return 0
}

local_init() {
   # Do nothig
   return 0
}

local_get() {
   # Do nothig
   return 0
}

local_put() {
   # Do nothig
   return 0
}

local_init

