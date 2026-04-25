#!/usr/bin/env bats
# Tests for lock_check_and_set() and lock_release() in lib/main.sh

load '../test_helper'

setup() {
   load_main_lib
   BAK_LOCK="${BATS_TMPDIR}/test_backup_$$.lock"
   BAK_OUTPUT="${BATS_TMPDIR}/bak_output_$$.txt"
   touch "$BAK_OUTPUT"
}

teardown() {
   rm -f "$BAK_LOCK" "$BAK_OUTPUT"
}

@test "lock_check_and_set: succeeds when no lock file exists" {
   run lock_check_and_set
   assert_success
}

@test "lock_check_and_set: creates the lock file" {
   lock_check_and_set
   assert_file_exists "$BAK_LOCK"
}

@test "lock_check_and_set: writes current PID to lock file" {
   lock_check_and_set
   run cat "$BAK_LOCK"
   assert_output "$BASHPID"
}

@test "lock_check_and_set: succeeds when lock file has a dead PID" {
   echo "999999999" > "$BAK_LOCK"
   run lock_check_and_set
   assert_success
}

@test "lock_check_and_set: fails when lock file holds a live PID" {
   echo "$$" > "$BAK_LOCK"
   run lock_check_and_set
   assert_failure
}

@test "lock_release: removes the lock file" {
   echo "$$" > "$BAK_LOCK"
   lock_release
   assert_file_not_exists "$BAK_LOCK"
}
