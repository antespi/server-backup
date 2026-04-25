#!/usr/bin/env bats
# Tests for lib/ftp.sh

load '../test_helper'

setup() {
   load_main_lib

   TEST_TMP="${BATS_TMPDIR}/ftp_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/bak_output.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/bak_output_ext.txt"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"

   # Set required FTP globals before sourcing.
   # BAK_CONFIG_PATH points to TEST_TMP where no .ftpcfg exists,
   # so ftp_init bails early and sets BAK_FTP_ERROR=1 — safe for all tests.
   export BAK_CONFIG_PATH="$TEST_TMP"
   export BAK_FTP_INSTANCE="test-instance"
   export BAK_FTP_CURRENT_FILE="current.txt"
   export CHMOD_BIN="chmod"

   # shellcheck source=../../lib/ftp.sh
   source "$PROJECT_ROOT/lib/ftp.sh"

   # Most tests start with a clean error state.
   BAK_FTP_ERROR=0
   BAK_FTP_CURRENT_PATH=""
}

teardown() {
   rm -rf "$TEST_TMP"
   rm -f "/tmp/$BAK_FTP_CURRENT_FILE"
}

# ── ftp_mount / ftp_umount ──────────────────────────────────────────────────

@test "ftp_mount: always succeeds" {
   run ftp_mount
   assert_success
}

@test "ftp_umount: always succeeds" {
   run ftp_umount
   assert_success
}

# ── ftp_environment_check ───────────────────────────────────────────────────

@test "ftp_environment_check: fails when BAK_FTP_ERROR is set" {
   BAK_FTP_ERROR=1
   run ftp_environment_check
   assert_failure
}

@test "ftp_environment_check: returns BAK_FTP_ERROR value" {
   BAK_FTP_ERROR=9
   run ftp_environment_check
   assert_equal "$status" "9"
}

@test "ftp_environment_check: fails when ncftp binary does not exist" {
   BAK_FTP_CMD_BIN="/no/such/ncftp"
   run ftp_environment_check
   assert_failure
   assert_output --partial "NcFTP is not installed"
}

@test "ftp_environment_check: succeeds when error is clear and ncftp exists" {
   BAK_FTP_CMD_BIN="$(make_stub ncftp 0)"
   run ftp_environment_check
   assert_success
}

# ── ftp_errmsg ──────────────────────────────────────────────────────────────

@test "ftp_errmsg: error 1 maps to 'could not connect to host'" {
   run ftp_errmsg 1
   assert_success
   assert_output --partial "could not connect to host"
   assert_output --partial "ERROR(1)"
}

@test "ftp_errmsg: error 2 maps to 'could not connect to host'" {
   run ftp_errmsg 2
   assert_output --partial "could not connect to host"
   assert_output --partial "ERROR(2)"
}

@test "ftp_errmsg: error 9 maps to 'login failed'" {
   run ftp_errmsg 9
   assert_output --partial "login failed"
   assert_output --partial "ERROR(9)"
}

@test "ftp_errmsg: other errors map to generic message" {
   run ftp_errmsg 5
   assert_output --partial "Invalid FTP configuration"
   assert_output --partial "ERROR(5)"
   refute_output --partial "could not connect"
   refute_output --partial "login failed"
}

# ── ftp_check ───────────────────────────────────────────────────────────────

@test "ftp_check: returns BAK_FTP_ERROR immediately when it is non-zero" {
   BAK_FTP_ERROR=3
   # Provide a real config file so the cat/grep prelude doesn't crash.
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   run ftp_check
   assert_equal "$status" "3"
}

@test "ftp_check: succeeds when check command succeeds" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 0)"
   run ftp_check
   assert_success
}

@test "ftp_check: fails when check command fails" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 9)"
   run ftp_check
   assert_equal "$status" "9"
}

@test "ftp_check: with init context redirects to NULL output" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 0)"
   : > "$BAK_OUTPUT_EXTENDED"
   run ftp_check 'init'
   assert_success
   # When ctx=init, output goes to NULL — extended log should remain empty.
   [ ! -s "$BAK_OUTPUT_EXTENDED" ]
}

# ── ftp_config_show ─────────────────────────────────────────────────────────

@test "ftp_config_show: reports ERROR status when BAK_FTP_ERROR is set" {
   BAK_FTP_ERROR=9
   run ftp_config_show
   assert_output --partial "ERROR (9)"
}

@test "ftp_config_show: reports OK when no error and config file present" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CMD_BIN="$(make_stub ncftpbin 0)"
   # ftp_check is sourced; override CHECK_BIN to succeed
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 0)"
   run ftp_config_show
   assert_output --partial "Status       : OK"
}

@test "ftp_config_show: reports config file not found when missing" {
   # No .ftpcfg in TEST_TMP
   run ftp_config_show
   assert_output --partial "File not found"
}

@test "ftp_config_show: reports NcFTP not installed when binary missing" {
   BAK_FTP_CMD_BIN="/no/such/ncftp"
   run ftp_config_show
   assert_output --partial "NcFTP is not installed"
}

# ── ftp_snapshot ────────────────────────────────────────────────────────────

@test "ftp_snapshot: fails immediately when BAK_FTP_ERROR is set" {
   BAK_FTP_ERROR=1
   run ftp_snapshot
   assert_failure
}

@test "ftp_snapshot: returns BAK_FTP_ERROR when set" {
   BAK_FTP_ERROR=7
   run ftp_snapshot
   assert_equal "$status" "7"
}

@test "ftp_snapshot: fails when PUT command fails" {
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 1)"
   run ftp_snapshot
   assert_failure
}

@test "ftp_snapshot: succeeds and sets BAK_FTP_CURRENT_PATH when PUT succeeds" {
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 0)"
   # Call directly so variable side-effects are visible
   ftp_snapshot
   assert_equal "$?" "0"
   assert [ -n "$BAK_FTP_CURRENT_PATH" ]
}

@test "ftp_snapshot: cleans up the temp current file after run" {
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 0)"
   ftp_snapshot
   [ ! -f "/tmp/$BAK_FTP_CURRENT_FILE" ]
}

# ── ftp_init ────────────────────────────────────────────────────────────────

@test "ftp_init: sets BAK_FTP_ERROR=1 when config file does not exist" {
   # No config file in TEST_TMP
   BAK_FTP_ERROR=0
   ftp_init
   assert_equal "$BAK_FTP_ERROR" "1"
}

@test "ftp_init: sets BAK_FTP_ERROR from ftp_check when check fails" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 9)"
   BAK_FTP_ERROR=0
   ftp_init || true
   assert_equal "$BAK_FTP_ERROR" "9"
}

@test "ftp_init: when current file exists remotely, reads BAK_FTP_CURRENT_PATH from it" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 0)"
   # GET stub: write a fake current file then exit 0
   local getstub="${BATS_TMPDIR}/stub_ncftpget_$$.sh"
   {
      echo "#!/bin/bash"
      echo "echo '2025-12-31' > /tmp/$BAK_FTP_CURRENT_FILE"
      echo "exit 0"
   } > "$getstub"
   chmod +x "$getstub"
   BAK_FTP_GET_BIN="$getstub"
   BAK_FTP_ERROR=0
   ftp_init
   assert_equal "$BAK_FTP_ERROR" "0"
   assert_equal "$BAK_FTP_CURRENT_PATH" "2025-12-31"
}

@test "ftp_init: when GET fails, creates a new current file via PUT" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 0)"
   BAK_FTP_GET_BIN="$(make_stub ncftpget 1)"
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 0)"
   BAK_FTP_ERROR=0
   ftp_init || true
   assert_equal "$BAK_FTP_ERROR" "0"
   assert [ -n "$BAK_FTP_CURRENT_PATH" ]
}

@test "ftp_init: when GET fails and PUT also fails, sets BAK_FTP_ERROR" {
   echo "host example.com" > "$BAK_FTP_CONFIG_FILE"
   echo "user u" >> "$BAK_FTP_CONFIG_FILE"
   echo "pass p" >> "$BAK_FTP_CONFIG_FILE"
   BAK_FTP_CHECK_BIN="$(make_stub ncftpls 0)"
   BAK_FTP_GET_BIN="$(make_stub ncftpget 1)"
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 4)"
   BAK_FTP_ERROR=0
   ftp_init || true
   assert_equal "$BAK_FTP_ERROR" "4"
}

# ── ftp_get ─────────────────────────────────────────────────────────────────

@test "ftp_get: fails immediately when BAK_FTP_ERROR is set" {
   BAK_FTP_ERROR=1
   run ftp_get "${TEST_TMP}/file.tar.gz"
   assert_failure
}

@test "ftp_get: returns BAK_FTP_ERROR value when set" {
   BAK_FTP_ERROR=9
   run ftp_get "${TEST_TMP}/file.tar.gz"
   assert_equal "$status" "9"
}

@test "ftp_get: fails when local file does not exist" {
   BAK_FTP_GET_BIN="$(make_stub ncftpget 0)"
   run ftp_get "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "ftp_get: succeeds when file exists and GET succeeds" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_FTP_GET_BIN="$(make_stub ncftpget 0)"
   run ftp_get "$testfile"
   assert_success
}

@test "ftp_get: fails when GET command returns error" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_FTP_GET_BIN="$(make_stub ncftpget 1)"
   run ftp_get "$testfile"
   assert_failure
}

# ── ftp_put ─────────────────────────────────────────────────────────────────

@test "ftp_put: fails immediately when BAK_FTP_ERROR is set" {
   BAK_FTP_ERROR=1
   run ftp_put "${TEST_TMP}/backup.tar.gz"
   assert_failure
}

@test "ftp_put: returns BAK_FTP_ERROR value when set" {
   BAK_FTP_ERROR=2
   run ftp_put "${TEST_TMP}/backup.tar.gz"
   assert_equal "$status" "2"
}

@test "ftp_put: fails when file does not exist" {
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 0)"
   run ftp_put "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "ftp_put: fails when PUT command fails" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake content" > "$testfile"
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 1)"
   run ftp_put "$testfile"
   assert_failure
}

@test "ftp_put: succeeds when file exists and PUT succeeds" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake content" > "$testfile"
   BAK_FTP_PUT_BIN="$(make_stub ncftpput 0)"
   run ftp_put "$testfile"
   assert_success
}
