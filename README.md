server-backup
=============

Backup system for Dedicated Servers or EC2 into different backends : S3, FTP, SFTP, USBHD, Local

Instalation
=============

Files to customize
=============
-   general.conf : General configuration

    1.  Email addresses for notifications
    2.  Customer name
    3.  Backends list

-   config.conf : Server configuration sources

    1.  Server configuration directories to backup

-   database.conf : Database configuration

    1.  Databases to backup

- sources.conf : Data sources

    1.  Server data directories to backup

- s3.conf : S3 Backend configuration

    1.  S3 bucket
    2.  Remember to set credentials in lib/s3/aws-php/config.inc.php

- local.conf : Local backend configuration

    1.  Local path
