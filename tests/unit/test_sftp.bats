#!/usr/bin/env bats
# Tests for lib/sftp.sh

load '../test_helper'

setup() {
   load_main_lib

   TEST_TMP="${BATS_TMPDIR}/sftp_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/bak_output.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/bak_output_ext.txt"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"

   # Set required SFTP globals before sourcing.
   # BAK_CONFIG_PATH points to TEST_TMP where no .sftpcfg exists,
   # so sftp_init bails early and sets BAK_SFTP_ERROR=1 — safe for all tests.
   export BAK_CONFIG_PATH="$TEST_TMP"
   export BAK_SFTP_INSTANCE="test-instance"
   export BAK_SFTP_CURRENT_FILE="current.txt"
   export BAK_SFTP_USER="testuser"
   export BAK_SFTP_HOSTS="host1.example.com"
   export CHMOD_BIN="chmod"

   # shellcheck source=../../lib/sftp.sh
   source "$PROJECT_ROOT/lib/sftp.sh"

   # Most tests start with a clean error state.
   BAK_SFTP_ERROR=0
   BAK_SFTP_CURRENT_PATH=""
}

teardown() {
   rm -rf "$TEST_TMP"
   rm -f "/tmp/$BAK_SFTP_CURRENT_FILE"
}

# ── sftp_mount / sftp_umount ────────────────────────────────────────────────

@test "sftp_mount: always succeeds" {
   run sftp_mount
   assert_success
}

@test "sftp_umount: always succeeds" {
   run sftp_umount
   assert_success
}

# ── sftp_errmsg ─────────────────────────────────────────────────────────────

@test "sftp_errmsg: returns formatted message with error code" {
   run sftp_errmsg 1
   assert_success
   assert_output --partial "ERROR(1)"
   assert_output --partial "Error in SFTP configuration"
}

@test "sftp_errmsg: includes specific error code in output" {
   run sftp_errmsg 42
   assert_output --partial "ERROR(42)"
}

# ── sftp_environment_check ──────────────────────────────────────────────────

@test "sftp_environment_check: fails when BAK_SFTP_ERROR is set" {
   BAK_SFTP_ERROR=1
   run sftp_environment_check
   assert_failure
}

@test "sftp_environment_check: returns specific BAK_SFTP_ERROR code" {
   BAK_SFTP_ERROR=5
   run sftp_environment_check
   assert_equal "$status" "5"
}

@test "sftp_environment_check: fails when sftp binary does not exist" {
   BAK_SFTP_CMD_BIN="/no/such/sftp"
   run sftp_environment_check
   assert_failure
   assert_output --partial "SFTP is not installed"
}

@test "sftp_environment_check: succeeds when error is clear and sftp exists" {
   BAK_SFTP_CMD_BIN="$(make_stub sftp 0)"
   run sftp_environment_check
   assert_success
}

# ── sftp_check ──────────────────────────────────────────────────────────────

@test "sftp_check: returns BAK_SFTP_ERROR immediately when it is non-zero" {
   BAK_SFTP_ERROR=3
   run sftp_check "host1.example.com"
   assert_equal "$status" "3"
}

@test "sftp_check: succeeds when sftp command succeeds" {
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   run sftp_check "host1.example.com"
   assert_success
}

@test "sftp_check: fails when sftp command fails" {
   BAK_SFTP_BIN="$(make_stub sftp 1)"
   run sftp_check "host1.example.com"
   assert_failure
}

@test "sftp_check: uses NULL output when ctx is 'init'" {
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   run sftp_check "host1.example.com" "init"
   assert_success
}

# ── sftp_snapshot ───────────────────────────────────────────────────────────

@test "sftp_snapshot: fails immediately when BAK_SFTP_ERROR is set" {
   BAK_SFTP_ERROR=1
   run sftp_snapshot
   assert_failure
}

@test "sftp_snapshot: returns specific error code when BAK_SFTP_ERROR is set" {
   BAK_SFTP_ERROR=7
   run sftp_snapshot
   assert_equal "$status" "7"
}

@test "sftp_snapshot: fails when sftp PUT command fails" {
   BAK_SFTP_BIN="$(make_stub sftp 1)"
   run sftp_snapshot
   assert_failure
}

@test "sftp_snapshot: succeeds and sets BAK_SFTP_CURRENT_PATH when sftp succeeds" {
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   # Call directly (not run) so variable side-effects are visible
   sftp_snapshot
   assert_equal "$?" "0"
   assert [ -n "$BAK_SFTP_CURRENT_PATH" ]
}

# ── sftp_init ───────────────────────────────────────────────────────────────

@test "sftp_init: sets BAK_SFTP_ERROR=1 when config file is missing" {
   # No .sftpcfg in BAK_CONFIG_PATH (TEST_TMP)
   BAK_SFTP_ERROR=0
   sftp_init
   assert_equal "$BAK_SFTP_ERROR" "1"
}

@test "sftp_init: leaves BAK_SFTP_ERROR=0 when sftp_check succeeds and get works" {
   # Create config file so sftp_init proceeds past the guard.
   touch "$BAK_SFTP_CONFIG_FILE"
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   BAK_SFTP_ERROR=0
   sftp_init || true
   assert_equal "$BAK_SFTP_ERROR" "0"
}

@test "sftp_init: sets BAK_SFTP_ERROR when sftp_check fails on host" {
   touch "$BAK_SFTP_CONFIG_FILE"
   BAK_SFTP_BIN="$(make_stub sftp 1)"
   BAK_SFTP_ERROR=0
   sftp_init || true
   assert [ "$BAK_SFTP_ERROR" -ne 0 ]
}

# ── sftp_config_show ────────────────────────────────────────────────────────

@test "sftp_config_show: shows OK when error is clear and config file exists" {
   touch "$BAK_SFTP_CONFIG_FILE"
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   BAK_SFTP_CMD_BIN="$(make_stub sftpcmd 0)"
   BAK_SFTP_ERROR=0
   run sftp_config_show
   assert_success
   assert_output --partial "Status       : OK"
}

@test "sftp_config_show: reports ERROR status when BAK_SFTP_ERROR is non-zero" {
   BAK_SFTP_ERROR=4
   run sftp_config_show
   assert_failure
   assert_output --partial "ERROR (4)"
}

@test "sftp_config_show: reports SFTP not installed when binary missing" {
   BAK_SFTP_CMD_BIN="/no/such/sftp"
   run sftp_config_show
   assert_output --partial "SFTP is not installed"
}

@test "sftp_config_show: reports config file not found" {
   # BAK_SFTP_CONFIG_FILE points to TEST_TMP/.sftpcfg which does not exist
   BAK_SFTP_ERROR=0
   BAK_SFTP_CMD_BIN="$(make_stub sftpcmd 0)"
   run sftp_config_show
   assert_output --partial "File not found"
}

# ── sftp_get ────────────────────────────────────────────────────────────────

@test "sftp_get: fails immediately when BAK_SFTP_ERROR is set" {
   BAK_SFTP_ERROR=1
   run sftp_get "${TEST_TMP}/file.tar.gz"
   assert_failure
}

@test "sftp_get: returns specific error code when BAK_SFTP_ERROR is set" {
   BAK_SFTP_ERROR=9
   run sftp_get "${TEST_TMP}/file.tar.gz"
   assert_equal "$status" "9"
}

@test "sftp_get: fails when local file does not exist" {
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   run sftp_get "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "sftp_get: succeeds when file exists and sftp succeeds" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   run sftp_get "$testfile"
   assert_success
}

@test "sftp_get: fails when sftp command returns error" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_SFTP_BIN="$(make_stub sftp 1)"
   run sftp_get "$testfile"
   assert_failure
}

# ── sftp_put ────────────────────────────────────────────────────────────────

@test "sftp_put: fails immediately when BAK_SFTP_ERROR is set" {
   BAK_SFTP_ERROR=1
   run sftp_put "${TEST_TMP}/backup.tar.gz"
   assert_failure
}

@test "sftp_put: returns specific error code when BAK_SFTP_ERROR is set" {
   BAK_SFTP_ERROR=8
   run sftp_put "${TEST_TMP}/backup.tar.gz"
   assert_equal "$status" "8"
}

@test "sftp_put: fails when file does not exist" {
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   run sftp_put "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "sftp_put: fails when sftp command fails" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake content" > "$testfile"
   BAK_SFTP_BIN="$(make_stub sftp 1)"
   run sftp_put "$testfile"
   assert_failure
}

@test "sftp_put: succeeds when file exists and sftp succeeds" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake content" > "$testfile"
   BAK_SFTP_BIN="$(make_stub sftp 0)"
   run sftp_put "$testfile"
   assert_success
}
