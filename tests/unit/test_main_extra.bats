#!/usr/bin/env bats
# Tests for additional helper/utility functions in lib/main.sh

load '../test_helper'

setup() {
   load_main_lib
   TEST_TMP="${BATS_TMPDIR}/main_extra_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/bak_output.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/bak_output_ext.txt"
   BAK_STATUS_FILE="${TEST_TMP}/last_status"
   BAK_MAIL_TEMP_FILE="${TEST_TMP}/mail.eml"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"
   BAK_TIMESTAMP=1700000000
   BAK_START_DATE="Mon Jan 1 12:00:00 UTC 2026"
}

teardown() { rm -rf "$TEST_TMP"; }

##################################################################
# status_save
##################################################################

@test "status_save: creates the status file" {
   status_save 0 || true
   assert_file_exists "$BAK_STATUS_FILE"
}

@test "status_save: writes 'Success' for error=0" {
   status_save 0 || true
   run grep "Success" "$BAK_STATUS_FILE"
   assert_success
}

@test "status_save: writes 'Error=5' for error=5" {
   status_save 5 || true
   run grep "Error=5" "$BAK_STATUS_FILE"
   assert_success
}

@test "status_save: status file contains BAK_TIMESTAMP" {
   status_save 0 || true
   run grep "^1700000000;" "$BAK_STATUS_FILE"
   assert_success
}

##################################################################
# log_start_print
##################################################################

@test "log_start_print: output file contains the name passed in" {
   log_start_print "MYBACKUP" || true
   run grep "MYBACKUP" "$BAK_OUTPUT"
   assert_success
}

@test "log_start_print: output file contains START" {
   log_start_print "MYBACKUP" || true
   run grep "START" "$BAK_OUTPUT"
   assert_success
}

##################################################################
# log_end_print
##################################################################

@test "log_end_print: output file contains the name passed in" {
   log_end_print "MYBACKUP" || true
   run grep "MYBACKUP" "$BAK_OUTPUT"
   assert_success
}

@test "log_end_print: output file contains END" {
   log_end_print "MYBACKUP" || true
   run grep "END" "$BAK_OUTPUT"
   assert_success
}

##################################################################
# executable_set
##################################################################

@test "executable_set: makes a non-executable file executable" {
   local f="${TEST_TMP}/script.sh"
   touch "$f"
   chmod -x "$f"
   executable_set "$f" || true
   assert [ -x "$f" ]
}

@test "executable_set: already-executable file stays executable" {
   local f="${TEST_TMP}/already_exec.sh"
   touch "$f"
   chmod +x "$f"
   executable_set "$f" || true
   assert [ -x "$f" ]
}

@test "executable_set: exits 1 for a missing file" {
   run executable_set "${TEST_TMP}/does_not_exist.sh"
   assert_failure
}

##################################################################
# mail_from_to_write
##################################################################

@test "mail_from_to_write: file contains 'To:' with address" {
   BAK_MAIL_TO="user@example.com"
   BAK_MAIL_CC=""
   mail_from_to_write || true
   run grep "To: user@example.com" "$BAK_MAIL_TEMP_FILE"
   assert_success
}

@test "mail_from_to_write: file contains 'Cc:' when BAK_MAIL_CC is set" {
   BAK_MAIL_TO="user@example.com"
   BAK_MAIL_CC="cc@example.com"
   mail_from_to_write || true
   run grep "Cc: cc@example.com" "$BAK_MAIL_TEMP_FILE"
   assert_success
}

@test "mail_from_to_write: file does not contain 'Cc:' when BAK_MAIL_CC is empty" {
   BAK_MAIL_TO="user@example.com"
   BAK_MAIL_CC=""
   mail_from_to_write || true
   run grep "Cc:" "$BAK_MAIL_TEMP_FILE"
   assert_failure
}

@test "mail_from_to_write: file contains 'From:' line" {
   BAK_MAIL_TO="user@example.com"
   BAK_MAIL_CC=""
   mail_from_to_write || true
   run grep "^From:" "$BAK_MAIL_TEMP_FILE"
   assert_success
}

##################################################################
# license_show / version_show
##################################################################

@test "license_show: output contains 'Server-Backup'" {
   run license_show
   assert_output --partial "Server-Backup"
}

@test "license_show: output contains the version number" {
   run license_show
   assert_output --partial "$BAK_VERSION"
}

@test "version_show: output contains 'Server-Backup'" {
   run version_show
   assert_output --partial "Server-Backup"
}

@test "version_show: output contains the version number" {
   run version_show
   assert_output --partial "$BAK_VERSION"
}

##################################################################
# help_show
##################################################################

@test "help_show: output contains 'Usage'" {
   run help_show
   assert_output --partial "Usage"
}

@test "help_show: output contains '--version'" {
   run help_show
   assert_output --partial "--version"
}

@test "help_show: output contains '--help'" {
   run help_show
   assert_output --partial "--help"
}

@test "help_show: output contains 'Server-Backup'" {
   run help_show
   assert_output --partial "Server-Backup"
}

##################################################################
# old_files_rm
##################################################################

@test "old_files_rm: empty PATH arg writes ERROR to BAK_OUTPUT" {
   old_files_rm "" "" || true
   run grep "ERROR" "$BAK_OUTPUT"
   assert_success
}

@test "old_files_rm: empty DAYS arg writes ERROR to BAK_OUTPUT" {
   old_files_rm "$TEST_TMP" "" || true
   run grep "ERROR" "$BAK_OUTPUT"
   assert_success
}

@test "old_files_rm: recent files are not removed" {
   local f="${TEST_TMP}/recent_file.txt"
   touch "$f"
   old_files_rm "$TEST_TMP" 30 || true
   assert_file_exists "$f"
}

@test "old_files_rm: with valid path and days writes message to BAK_OUTPUT" {
   old_files_rm "$TEST_TMP" 30 || true
   run grep "Deleting" "$BAK_OUTPUT"
   assert_success
}
