Server-Backup
=============

Backup system for Dedicated Servers or EC2 into different backends :
S3, LOCAL, FTP, SFTP, USBHD, WEBDAV.
Also support backup encryption using any algorithm supported by OpenSSL library.



Installation
============

1.    Connect to your server (dedicated server or Amazon EC2) at a root ssh shell.
2.    Go to root home : cd /root
3.    Clone this repo : git clone https://github.com/antespi/server-backup.git
4.    Go to Server-Backup dir : cd server-backup
5.    Execute it for first setup : ./backup.sh
6.    Edit configuration files (see Configuration section below)
7.    If AWS S3 backend enabled (enabled by default), you will need to get
an AWS account, AWS credentials (accessKey and secretKey) and create
an S3 Bucket. Be sure that user has enoght rights to get and put files
to that S3 Bucket.
8.    Configure a cron file (/etc/cron.d/backup) like this

        0  1 * *   *  root  /root/server-backup/backup.sh &> /root/server-backup/last_backup.log
        0 22 * *   6  root  /root/server-backup/snapshot.sh &> /root/server-backup/last_snapshot.log

9.    If local backend enabled (enabled by default), create an FTP (or SFTP)
account for fetching backup with read acces to local folder (/backup/local by default)



Configuration
=============

-   config.conf : Server configuration sources

    1.  Server configuration directories to backup

-   database.conf : Database configuration

    1.  Databases to backup
    2.  Create a .my.cnf file in /root : nano /root/.my.cnf

        [mysqldump]
        host = localhost
        user = root
        password = <your-mysql-root-pass>

        [mysql]
        host = localhost
        user = root
        password = <your-mysql-root-pass>

    3. Be sure this file is only root readable

        # chmod 640 /root/.my.cnf
        # chown root:root /root/.my.cnf


-   sources.conf : Data sources

    1.  Server data directories to backup : path,depth,inc
        - path  : Data directory to backup
        - depth : if 0, make backup of 'path' directory
                  if 1, make a separate backup os each subfolder in 'path' directory
                  if 2, make a separate backup os each subfolder/subfolder in 'path' directory
                  and so on
        - inc   : if 0, make full backup every time
                  if 1, make incremental backups

-   s3.conf : S3 Backend configuration

    1.  S3 bucket
    2.  Remember to set credentials in lib/s3/aws-php/config.inc.php

-   local.conf : Local backend configuration

    1.  Local path

-   ecn.key : Encryption key

    1. Change key. You can create an aleatory key with pwgen

        # pwgen -B -s 64

    2. Be sure this file is only root readable

        # chmod 640 config/enc.key
        # chown root:root config/enc.key

-   general.conf : General configuration

    1.  Email addresses for notifications, disabled by default
    2.  Customer name
    3.  Backends list
    4.  Set BAK_DEBUG to 0, to preform a real backup
    5.  Set BAK_ENABLED to 1, to activate backup process



Environment
===========

backup.sh will check environment before execute any backup command.
In particular Server-Backup will need:

-   Bash shell
-   Tar compress with Gzip and Bzip2 support
-   Sendmail (postfix, exim, ...)
-   OpenSSL (for encrypt, enabled by default)

If backup do not start and show environment error, please check that external programs are in the path and are executable.

Maybe you will have to give execution rights to this programs:

    # chmod +x /root/server-backup/lib/sr.sh
    # chmod +x /root/server-backup/backup.sh
    # chmod +x /root/server-backup/snapshot.sh

If you enable AWS S3 backend (enabled by default) then be sure that you have installed php5 and php5-curl, and other AWS SDK for PHP requirements. [More info](http://docs.amazonwebservices.com/AWSSdkDocsPHP/latest/DeveloperGuide/php-dg-setup.html)

    # apt-get install php5 php5-curl



Backup process
==============

This is what backup.sh script do each time is invoked by you or by a cron job

1.   Load main configuration files from ./config folder : general.conf, database.conf, config.conf
2.   Load backend configuration files (only enabled beackends)
3.   Load main library from ./lib folder : main.sh
4.   Check environment
5.   Create directories (if needed)
6.   Read data sources configuration : ./config/sources.conf
7.   Backup server configuration
8.   Backup databases
9.   Backup data sources
10.  Read local storage info
11.  Delete old log files
12.  Send a email report (if enabled)

This is what snapshot.sh script do each time is invoked by you or by a cron job (TODO)

1.   Remove historical files (for incremental backups) : /backup/historical
2.   Make snapshot operation for each backend (backend specific process)



TODO
====

This is the first version, there are some tasks to do ;)

-    Snapshot script
-    More backends: FTP, USBHD, SFTP, WEBDAV
-    Backup of PostgreSQL databases
-    Backup of SQlite databases



LICENSE
=======

Server-Backup is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

Server-Backup is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with Server-Backup. For license details you can read
[LICENSE.md](https://github.com/antespi/server-backup/blob/master/LICENSE.md)
file. Also you can read GPLv3 from [GNU Licenses](http://www.gnu.org/licenses/).



AUTHOR
======

Copyright (C) 2012<br />
Antonio Espinosa<br />
Email    : aespinosa at teachnova dot com<br />
Twitter  : [@antespi](http://twitter.com/antespi)<br />
LinkedIn : [Antonio Espinosa](http://es.linkedin.com/in/antonioespinosa)<br />
Web      : [Teachnova](http://www.teachnova.com)
