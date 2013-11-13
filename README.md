Server-Backup
=============

Backup system for Dedicated Servers or EC2 into different backends :
S3, LOCAL, FTP, SFTP, USBHD, WEBDAV.
Also support backup encryption using any algorithm supported by OpenSSL library.



Pre-Installation
================

This software require third-party applications for enabling some features:

-   S3 Backend : Need s3cmd from http://s3tools.org/s3cmd

    1.    sudo apt-get install s3cmd
    2.    Get a AWS account if you don't have one already
    3.    Configure an IAM user for access to S3 buckets and download its credentials (Access Key and Secret Key)
    4.    s3cmd --configure
        -    Introduce AWS Access Key
        -    Introduce AWS Secret Key
        -    Left 'Encryption password' blank
        -    Let 'Path to GPG program' value by default
        -    Use HTTPS protocol : Yes
    5. Remember path of .s3cfg generated file for later

-   FTP Backend : Need ncftp from http://www.ncftp.com/ncftp/

    1.    sudo apt-get install ncftp



Installation
============

1.    Connect to your server (dedicated server or Amazon EC2) at a root ssh shell.
2.    Go to root home : cd /root
3.    Clone this repo : git clone https://github.com/antespi/server-backup.git
4.    Go to Server-Backup dir : cd server-backup
5.    Execute it for first setup : ./backup.sh --config
6.    Edit configuration files (see Configuration section below)
7.    If AWS S3 backend enabled (enabled by default), you will need to get
an AWS account, AWS credentials (accessKey and secretKey) and create
an S3 Bucket. Be sure that user has enoght rights to get and put files
to that S3 Bucket. You need s3cmd installed and configured.
8.    Configure a cron file like this

/etc/cron.d/backup

    0   1    * * 1-6  root  /root/server-backup/backup.sh &> /root/server-backup/last_backup.log
    0  22    * * 5    root  /root/server-backup/backup.sh --snapshot &> /root/server-backup/last_snapshot.log

Or copy from sample

    # cp -a /root/server-backup/cron-backup-sample /etc/cron.d/backup

9.    If local backend enabled (enabled by default), create an FTP (or SFTP)
account for fetching backup with read acces to local folder (/backup/local by default)



Configuration
=============

-   config.conf : Server configuration sources

    1.  Server configuration directories to backup


-   database.conf : Database configuration

    1.  Databases to backup
    2.  Create a .my.cnf file in /root : 

nano /root/.my.cnf

        [mysqldump]
        host = localhost
        user = root
        password = <your-mysql-root-pass>

        [mysql]
        host = localhost
        user = root
        password = <your-mysql-root-pass>


Be sure this file is only root readable

        # chmod 640 /root/.my.cnf
        # chown root:root /root/.my.cnf


-   sources.conf : Data sources

    1.  Server data directories to backup : path,depth,inc
        - path  : Data directory to backup
        - depth : if 0, make backup of 'path' directory
                  if 1, make a separate backup of each subfolder in 'path' directory
                  if 2, make a separate backup of each subfolder/subfolder in 'path' directory
                  and so on
                  WARNING : With depth > 0, files and folders in parents directory will
                            not included in backup. For example: '/var/www,1,0'
                            will backup '/var/www/website1' and '/var/www/website2'
                            directories separately but not '/var/www/index.html' file
                            Run ./backup.sh -c to see what directories will backup
        - inc   : if 0, make full backup every time
                  if 1, make incremental backups


-   s3.conf : S3 Backend configuration

    1.  S3 bucket
    2.  Copy .s3cfg generated after (in pre-installation) to /root/server-backup

/root/server-backup

        # chmod 640 /root/server-backup/config/.s3cfg
        # chmod root:root /root/server-backup/config/.s3cfg

We recommend to change chunk sizes to improve upload performance in big files

        # nano /root/server-backup/config/.s3cfg
            multipart_chunk_size_mb = 1024
            recv_chunk = 81920
            send_chunk = 81920


-   ftp.conf : FTP Backend configuration

    1. Create .ftpcfg file with host, user and password info

/root/server-backup/config/.ftpcfg

        # nano /root/server-backup/config/.ftpcfg
            host sphygmomanometer.ncftp.com
            user gleason
            pass mypasswd


-   local.conf : Local backend configuration

    1.  Local path


-   ecn.key : Encryption key

    1. Change key. You can create a random key with pwgen

Random key

        # pwgen -B -s 64

Be sure this file is only root readable

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

This is what 'backup.sh --snapshot' script do each time is invoked by you or by a cron job (TODO)

1.   Remove historical files (for incremental backups) : /backup/historical
2.   Make snapshot operation for each backend (backend specific process)



Restore process
===============

You can get any .tar.gz.enc file located in local folder (or any activated backend: S3, FTP). 
Then you can manually decrypt and decompress it like this:

    # openssl enc -aes-256-cbc -d -salt -pass file:/root/server-backup/config/enc.key -in file.tar.gz.enc -out file.tar.gz
    # tar -xzf file.tar.gz


TODO
====

This is the second version, there are some tasks to do yet ;)

-    More backends: USBHD, SFTP, WEBDAV
-    Testing of FTP backend
-    Backup of PostgreSQL databases
-    Backup of SQlite databases
-    Restore file option
-    List file option



CHANGE LOG
==========

v0.2 : Oct 2013

-    Use of s3cmd as toolkit to connect to S3 Backend
-    FTP Backend, not fully tested!
-    Snapshot option


v0.1 : Nov 2012

-    First version



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
[LICENSE.md](https://github.com/Teachnova/server-backup/blob/master/LICENSE.md)
file. Also you can read GPLv3 from [GNU Licenses](http://www.gnu.org/licenses/).



AUTHOR
======

Copyright (C) 2012,2013<br />
Antonio Espinosa<br />
Email    : aespinosa at teachnova dot com<br />
Twitter  : [@antespi](http://twitter.com/antespi)<br />
LinkedIn : [Antonio Espinosa](http://es.linkedin.com/in/antonioespinosa)<br />
Web      : [Teachnova](http://www.teachnova.com)
