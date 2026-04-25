#!/usr/bin/env bats
# Tests for utility functions: file_size, dir_size, is_function

load '../test_helper'

setup() {
   load_main_lib
   TEST_TMP="${BATS_TMPDIR}/utils_$$"
   mkdir -p "$TEST_TMP"
}

teardown() {
   rm -rf "$TEST_TMP"
}

# --- file_size ---

@test "file_size: returns a non-zero size for an existing file" {
   echo "hello world" > "$TEST_TMP/sample.txt"
   run file_size "$TEST_TMP/sample.txt"
   assert_success
   refute_output "0"
   assert_output --regexp '^[0-9]'
}

@test "file_size: returns 0 for a non-existent file" {
   run file_size "$TEST_TMP/nonexistent.txt"
   assert_success
   assert_output "0"
}

# --- dir_size ---

@test "dir_size: returns a size for an existing directory" {
   echo "content" > "$TEST_TMP/file.txt"
   run dir_size "$TEST_TMP"
   assert_success
   assert_output --regexp '^[0-9]'
}

@test "dir_size: returns 0 for a non-existent directory" {
   run dir_size "$TEST_TMP/no_such_dir"
   assert_success
   assert_output "0"
}

# --- is_function ---

@test "is_function: returns true for a known function" {
   run is_function contains
   assert_success
}

@test "is_function: returns true for another known function" {
   run is_function file_size
   assert_success
}

@test "is_function: returns false for an unknown name" {
   run is_function totally_not_a_function_xyz
   assert_failure
}

@test "is_function: returns false for a variable name" {
   BAK_TEST_VAR="not a function"
   run is_function BAK_TEST_VAR
   assert_failure
}
