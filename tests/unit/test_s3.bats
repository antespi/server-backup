#!/usr/bin/env bats
# Tests for lib/s3.sh

load '../test_helper'

setup() {
   load_main_lib

   TEST_TMP="${BATS_TMPDIR}/s3_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/bak_output.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/bak_output_ext.txt"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"

   # Set required S3 globals before sourcing.
   # BAK_CONFIG_PATH points to TEST_TMP where no .s3cfg exists,
   # so s3_init bails early and sets BAK_S3_ERROR=1 — safe for all tests.
   export BAK_CONFIG_PATH="$TEST_TMP"
   export BAK_S3_BUCKET="test-bucket"
   export BAK_S3_INSTANCE="test-instance"
   export BAK_S3_CURRENT_FILE="current.txt"

   # shellcheck source=../../lib/s3.sh
   source "$PROJECT_ROOT/lib/s3.sh"

   # Most tests start with a clean error state.
   BAK_S3_ERROR=0
   BAK_S3_CURRENT_PATH=""
}

teardown() {
   rm -rf "$TEST_TMP"
   rm -f "/tmp/$BAK_S3_CURRENT_FILE"
}

# ── s3_mount / s3_umount ────────────────────────────────────────────────────

@test "s3_mount: always succeeds" {
   run s3_mount
   assert_success
}

@test "s3_umount: always succeeds" {
   run s3_umount
   assert_success
}

# ── s3_environment_check ────────────────────────────────────────────────────

@test "s3_environment_check: fails when BAK_S3_ERROR is set" {
   BAK_S3_ERROR=1
   run s3_environment_check
   assert_failure
}

@test "s3_environment_check: fails when s3cmd binary does not exist" {
   BAK_S3_CMD_BIN="/no/such/s3cmd"
   run s3_environment_check
   assert_failure
}

@test "s3_environment_check: succeeds when error is clear and s3cmd exists" {
   BAK_S3_CMD_BIN="$(make_stub s3cmd 0)"
   run s3_environment_check
   assert_success
}

# ── s3_check ────────────────────────────────────────────────────────────────

@test "s3_check: returns BAK_S3_ERROR immediately when it is non-zero" {
   BAK_S3_ERROR=3
   run s3_check
   assert_equal "$status" "3"
}

@test "s3_check: fails when autocheck output contains ERROR" {
   BAK_S3_AUTOCHECK_BIN="$(make_stub s3autocheck 0 "ERROR: Bucket does not exist")"
   run s3_check
   assert_failure
}

@test "s3_check: succeeds when autocheck output has no ERROR" {
   BAK_S3_AUTOCHECK_BIN="$(make_stub s3autocheck 0 "s3://test-bucket  (bucket)")"
   run s3_check
   assert_success
}

# ── s3_snapshot ──────────────────────────────────────────────────────────────

@test "s3_snapshot: fails immediately when BAK_S3_ERROR is set" {
   BAK_S3_ERROR=1
   run s3_snapshot
   assert_failure
}

@test "s3_snapshot: fails when PUT command fails" {
   BAK_S3_PUT_BIN="$(make_stub s3put 1)"
   run s3_snapshot
   assert_failure
}

@test "s3_snapshot: succeeds and sets BAK_S3_CURRENT_PATH when PUT succeeds" {
   BAK_S3_PUT_BIN="$(make_stub s3put 0)"
   # Call directly (not run) so variable side-effects are visible
   s3_snapshot
   assert_equal "$?" "0"
   assert [ -n "$BAK_S3_CURRENT_PATH" ]
}

# ── s3_get ───────────────────────────────────────────────────────────────────

@test "s3_get: fails immediately when BAK_S3_ERROR is set" {
   BAK_S3_ERROR=1
   run s3_get "${TEST_TMP}/file.tar.gz"
   assert_failure
}

@test "s3_get: fails when local file does not exist" {
   BAK_S3_GET_BIN="$(make_stub s3get 0)"
   run s3_get "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "s3_get: succeeds when file exists and GET succeeds" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_S3_GET_BIN="$(make_stub s3get 0)"
   run s3_get "$testfile"
   assert_success
}

@test "s3_get: fails when GET command returns error" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_S3_GET_BIN="$(make_stub s3get 1)"
   run s3_get "$testfile"
   assert_failure
}

# ── s3_put ───────────────────────────────────────────────────────────────────

@test "s3_put: fails immediately when BAK_S3_ERROR is set" {
   BAK_S3_ERROR=1
   run s3_put "${TEST_TMP}/backup.tar.gz"
   assert_failure
}

@test "s3_put: fails when file does not exist" {
   run s3_put "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "s3_put: fails when PUT command fails" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake content" > "$testfile"
   _s3cfg_with_chunk_size
   BAK_S3_PUT_BIN="$(make_stub s3put 1)"
   run s3_put "$testfile"
   assert_failure
}

@test "s3_put: returns 2 when PUT succeeds but MD5 does not match" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake content" > "$testfile"
   _s3cfg_with_chunk_size
   BAK_S3_PUT_BIN="$(make_stub s3put 0)"
   BAK_S3_EXISTS_BIN="$(make_stub s3exists 0 "MD5 sum: aaaa")"
   MD5SUM_BIN="$(make_stub md5sum 0 "bbbb  $testfile")"
   BAK_S3_MD5_BIN="$(make_stub s3md5 0 "cccc")"
   run s3_put "$testfile"
   assert_equal "$status" "2"
}

@test "s3_put: succeeds when PUT succeeds and MD5 matches" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   local md5="abc123def456"
   echo "fake content" > "$testfile"
   _s3cfg_with_chunk_size
   BAK_S3_PUT_BIN="$(make_stub s3put 0)"
   BAK_S3_EXISTS_BIN="$(make_stub s3exists 0 "MD5 sum: $md5")"
   MD5SUM_BIN="$(make_stub md5sum 0 "$md5  $testfile")"
   BAK_S3_MD5_BIN="$(make_stub s3md5 0 "$md5")"
   run s3_put "$testfile"
   assert_success
}

# ── helpers ──────────────────────────────────────────────────────────────────

# Write a minimal .s3cfg and point BAK_S3_CONFIG_FILE at it.
# Required by s3_put to read multipart_chunk_size_mb.
_s3cfg_with_chunk_size() {
   local cfg="${TEST_TMP}/.s3cfg"
   echo "multipart_chunk_size_mb = 15" > "$cfg"
   BAK_S3_CONFIG_FILE="$cfg"
}
