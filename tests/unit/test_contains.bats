#!/usr/bin/env bats
# Tests for the contains() function in lib/main.sh

load '../test_helper'

setup() {
   load_main_lib
}

@test "contains: returns true when value matches last element of array" {
   # Convention: all args except last = array elements, last arg = value to find
   run contains "apple" "banana" "cherry" "cherry"
   assert_success
}

@test "contains: returns true when value matches first element" {
   run contains "apple" "banana" "cherry" "apple"
   assert_success
}

@test "contains: returns true for single-element array match" {
   run contains "only" "only"
   assert_success
}

@test "contains: returns false when value is not in array" {
   run contains "apple" "banana" "cherry" "grape"
   assert_failure
}

@test "contains: returns false for single-element array no match" {
   run contains "only" "other"
   assert_failure
}

@test "contains: returns false when called with only one argument" {
   run contains "apple"
   assert_failure
}
