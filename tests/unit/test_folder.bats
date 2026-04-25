#!/usr/bin/env bats
# Tests for lib/folder.sh

load '../test_helper'

setup() {
   load_main_lib

   TEST_TMP="${BATS_TMPDIR}/folder_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/bak_output.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/bak_output_ext.txt"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"

   # Globals required by folder.sh before sourcing
   export BAK_FOLDER_PATH="$TEST_TMP/folder"
   export BAK_FOLDER_CURRENT_FILE="current.txt"

   # shellcheck source=../../lib/folder.sh
   source "$PROJECT_ROOT/lib/folder.sh"

   # Reset error/state vars after init so tests start clean.
   BAK_FOLDER_ERROR=0
   BAK_FOLDER_CURRENT_PATH=""
}

teardown() {
   rm -rf "$TEST_TMP"
   rm -f "/tmp/$BAK_FOLDER_CURRENT_FILE"
}

# ── folder_check ─────────────────────────────────────────────────────────────

@test "folder_check: returns 0 when BAK_FOLDER_ERROR is 0" {
   BAK_FOLDER_ERROR=0
   run folder_check
   assert_success
}

@test "folder_check: returns BAK_FOLDER_ERROR when non-zero" {
   BAK_FOLDER_ERROR=5
   run folder_check
   assert_equal "$status" "5"
}

# ── folder_config_show ───────────────────────────────────────────────────────

@test "folder_config_show: shows OK status when no error" {
   BAK_FOLDER_ERROR=0
   run folder_config_show
   assert_success
   assert_output --partial "Status       : OK"
}

@test "folder_config_show: shows ERROR status when BAK_FOLDER_ERROR set" {
   BAK_FOLDER_ERROR=2
   run folder_config_show
   assert_success
   assert_output --partial "Status       : ERROR (2)"
}

# ── folder_environment_check ─────────────────────────────────────────────────

@test "folder_environment_check: always succeeds" {
   run folder_environment_check
   assert_success
}

# ── folder_umount ────────────────────────────────────────────────────────────

@test "folder_umount: always succeeds" {
   run folder_umount
   assert_success
}

# ── folder_init ──────────────────────────────────────────────────────────────

@test "folder_init: leaves BAK_FOLDER_ERROR at 0 when check passes" {
   BAK_FOLDER_ERROR=0
   folder_init
   assert_equal "$BAK_FOLDER_ERROR" "0"
}

@test "folder_init: preserves non-zero BAK_FOLDER_ERROR" {
   BAK_FOLDER_ERROR=4
   folder_init || true
   assert_equal "$BAK_FOLDER_ERROR" "4"
}

# ── folder_snapshot ──────────────────────────────────────────────────────────

@test "folder_snapshot: fails immediately when BAK_FOLDER_ERROR is set" {
   BAK_FOLDER_ERROR=1
   run folder_snapshot
   assert_failure
}

@test "folder_snapshot: fails when PUT command fails" {
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 1)"
   run folder_snapshot
   assert_failure
}

@test "folder_snapshot: succeeds and sets BAK_FOLDER_CURRENT_PATH when PUT succeeds" {
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 0)"
   folder_snapshot
   assert_equal "$?" "0"
   assert [ -n "$BAK_FOLDER_CURRENT_PATH" ]
}

# ── folder_mount ─────────────────────────────────────────────────────────────

@test "folder_mount: fails immediately when BAK_FOLDER_ERROR is set" {
   BAK_FOLDER_ERROR=1
   run folder_mount
   assert_failure
}

@test "folder_mount: reads existing current file and sets BAK_FOLDER_CURRENT_PATH" {
   # GET succeeds — folder_mount will cat /tmp/$BAK_FOLDER_CURRENT_FILE.
   # Pre-create that file with known content; stub GET to be a no-op success.
   echo "2025-12-31" > "/tmp/$BAK_FOLDER_CURRENT_FILE"
   BAK_FOLDER_GET_BIN="$(make_stub folderget 0)"
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 0)"
   folder_mount
   assert_equal "$BAK_FOLDER_CURRENT_PATH" "2025-12-31"
}

@test "folder_mount: creates current file via PUT when GET fails" {
   # GET fails — folder_mount writes a fresh date file then PUTs it.
   BAK_FOLDER_GET_BIN="$(make_stub folderget 1)"
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 0)"
   folder_mount || true
   assert [ -n "$BAK_FOLDER_CURRENT_PATH" ]
   assert_equal "$BAK_FOLDER_ERROR" "0"
}

@test "folder_mount: sets BAK_FOLDER_ERROR when both GET and PUT fail" {
   BAK_FOLDER_GET_BIN="$(make_stub folderget 1)"
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 1)"
   folder_mount || true
   assert [ "$BAK_FOLDER_ERROR" -ne 0 ]
}

@test "folder_mount: creates folder dir when it does not exist" {
   rm -rf "$BAK_FOLDER_PATH"
   BAK_FOLDER_GET_BIN="$(make_stub folderget 1)"
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 0)"
   folder_mount || true
   assert [ -d "$BAK_FOLDER_PATH" ]
}

# ── folder_get ───────────────────────────────────────────────────────────────

@test "folder_get: fails immediately when BAK_FOLDER_ERROR is set" {
   BAK_FOLDER_ERROR=1
   run folder_get "${TEST_TMP}/file.tar.gz"
   assert_failure
}

@test "folder_get: fails when local file does not exist" {
   BAK_FOLDER_GET_BIN="$(make_stub folderget 0)"
   run folder_get "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "folder_get: succeeds when file exists and GET succeeds" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_FOLDER_GET_BIN="$(make_stub folderget 0)"
   run folder_get "$testfile"
   assert_success
}

@test "folder_get: fails when GET command returns error" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   touch "$testfile"
   BAK_FOLDER_GET_BIN="$(make_stub folderget 1)"
   run folder_get "$testfile"
   assert_failure
}

# ── folder_put ───────────────────────────────────────────────────────────────

@test "folder_put: fails immediately when BAK_FOLDER_ERROR is set" {
   BAK_FOLDER_ERROR=1
   run folder_put "${TEST_TMP}/backup.tar.gz"
   assert_failure
}

@test "folder_put: fails when file does not exist" {
   mkdir -p "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH"
   run folder_put "${TEST_TMP}/nonexistent.tar.gz"
   assert_failure
}

@test "folder_put: succeeds when file exists and PUT succeeds" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake" > "$testfile"
   BAK_FOLDER_CURRENT_PATH="snap"
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 0)"
   run folder_put "$testfile"
   assert_success
}

@test "folder_put: fails when PUT command fails" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake" > "$testfile"
   BAK_FOLDER_CURRENT_PATH="snap"
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 1)"
   run folder_put "$testfile"
   assert_failure
}

@test "folder_put: creates destination directory when missing" {
   local testfile="${TEST_TMP}/backup.tar.gz"
   echo "fake" > "$testfile"
   BAK_FOLDER_CURRENT_PATH="newsnap"
   rm -rf "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH"
   BAK_FOLDER_PUT_BIN="$(make_stub folderput 0)"
   run folder_put "$testfile"
   assert_success
   assert [ -d "$BAK_FOLDER_PATH/$BAK_FOLDER_CURRENT_PATH" ]
}
