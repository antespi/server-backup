#! /usr/bin/env php
<?php
// Server-Backup  Copyright (C) 2012
//                Antonio Espinosa <aespinosa at teachnova dot com>
//
// This file is part of Server-Backup by Teachnova (www.teachnova.com)
//
// Server-Backup is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Server-Backup is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Server-Backup.  If not, see <http://www.gnu.org/licenses/>.

   // Include the SDK
   require_once dirname(__FILE__) . '/aws-php/sdk.class.php';

   function help_show($error = '', $errno = 0) {
      global $argv;

      if (!empty($error))
         echo "ERROR - $error" . PHP_EOL;
      echo 'Usage : php ' . $argv[0] . ' <bucket> <folder>' . PHP_EOL;
      echo '   bucket - Bucket name' . PHP_EOL;
      echo '   folder - Folder name' . PHP_EOL;
      exit($errno);
   }

   $bucket = '';
   $folder = '';

   if (!empty($argv)){
      // Mandatory : Bucket name
      if (!empty($argv[1])) $bucket = $argv[1];
      else help_show('No bucket name specified', 1);

      // Mandatory : Folder name
      if (!empty($argv[2])) $folder = $argv[2];
      else help_show('No folder name specified', 2);
      $folder = rtrim($folder, '/');
   }

   // Instantiate the AmazonS3 class
   $s3 = new AmazonS3();

   $folder = $folder . '/';
   $response = $s3->create_object($bucket, $folder,
      array('body'      => '',
            'length'    => 0)
   );

   // echo "RESPONSE = " . var_export($response, true) . PHP_EOL;

   if ($response->isOK()) {
      exit(0);
   } else if ($response->status == 404) {
      echo "ERROR : NOT FOUND" . PHP_EOL;
      exit(1);
   } else if ($response->status == 403) {
      echo "ERROR : FORBBIDEN" . PHP_EOL;
      exit(1);
   }

   echo "ERROR : $response->status status" . PHP_EOL;
   exit(0);
