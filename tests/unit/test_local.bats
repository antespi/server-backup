#!/usr/bin/env bats
# Tests for lib/local.sh

load '../test_helper'

setup() {
   load_main_lib

   TEST_TMP="${BATS_TMPDIR}/local_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/bak_output.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/bak_output_ext.txt"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"

   # Set globals required by local.sh before sourcing it.
   export BAK_LOCAL_PATH="${TEST_TMP}/local_backup"
   mkdir -p "$BAK_LOCAL_PATH"

   # shellcheck source=../../lib/local.sh
   source "$PROJECT_ROOT/lib/local.sh"
}

teardown() {
   rm -rf "$TEST_TMP"
}

# ── local_check ─────────────────────────────────────────────────────────────

@test "local_check: always succeeds" {
   run local_check
   assert_success
}

# ── local_config_show ───────────────────────────────────────────────────────

@test "local_config_show: prints Local Configuration header" {
   run local_config_show
   assert_success
   assert_output --partial "Local Configuration"
}

@test "local_config_show: includes BAK_LOCAL_PATH value" {
   run local_config_show
   assert_success
   assert_output --partial "$BAK_LOCAL_PATH"
}

@test "local_config_show: reports Status OK" {
   run local_config_show
   assert_success
   assert_output --partial "Status       : OK"
}

# ── local_snapshot ──────────────────────────────────────────────────────────

@test "local_snapshot: always succeeds (no-op)" {
   run local_snapshot
   assert_success
   assert_equal "$output" ""
}

# ── local_environment_check ─────────────────────────────────────────────────

@test "local_environment_check: always succeeds (no-op)" {
   run local_environment_check
   assert_success
   assert_equal "$output" ""
}

# ── local_mount / local_umount ──────────────────────────────────────────────

@test "local_mount: always succeeds (no-op)" {
   run local_mount
   assert_success
   assert_equal "$output" ""
}

@test "local_umount: always succeeds (no-op)" {
   run local_umount
   assert_success
   assert_equal "$output" ""
}

# ── local_init ──────────────────────────────────────────────────────────────

@test "local_init: always succeeds (no-op)" {
   run local_init
   assert_success
   assert_equal "$output" ""
}

# ── local_get ───────────────────────────────────────────────────────────────

@test "local_get: succeeds with no arguments (no-op)" {
   run local_get
   assert_success
}

@test "local_get: succeeds when target file does not exist" {
   run local_get "${TEST_TMP}/nonexistent.tar.gz"
   assert_success
}

@test "local_get: succeeds when target file exists" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   run local_get "$testfile"
   assert_success
}

# ── local_put ───────────────────────────────────────────────────────────────

@test "local_put: succeeds with no arguments (no-op)" {
   run local_put
   assert_success
}

@test "local_put: succeeds when source file does not exist" {
   run local_put "${TEST_TMP}/nonexistent.tar.gz"
   assert_success
}

@test "local_put: succeeds when source file exists" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake content" > "$testfile"
   run local_put "$testfile"
   assert_success
}
