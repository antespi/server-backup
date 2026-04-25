#!/usr/bin/env bats
# Tests for source_config_read() in lib/main.sh

load '../test_helper'

setup() {
   load_main_lib
   BAK_OUTPUT="${BATS_TMPDIR}/bak_output_$$.txt"
   touch "$BAK_OUTPUT"
}

teardown() {
   rm -f "$BAK_OUTPUT"
}

@test "source_config_read: returns 0 for a valid file" {
   run source_config_read "${PROJECT_ROOT}/tests/fixtures/sample.sources.conf"
   assert_success
}

@test "source_config_read: returns 1 for a missing file" {
   run source_config_read "/tmp/does_not_exist_$$.conf"
   assert_failure
}

@test "source_config_read: parses first entry source, depth and inc" {
   source_config_read "${PROJECT_ROOT}/tests/fixtures/sample.sources.conf"
   assert_equal "${BAK_SOURCES_CONFIG_SOURCE[0]}" "/var/www"
   assert_equal "${BAK_SOURCES_CONFIG_DEPTH[0]}"  "1"
   assert_equal "${BAK_SOURCES_CONFIG_INC[0]}"    "1"
}

@test "source_config_read: parses second entry correctly" {
   source_config_read "${PROJECT_ROOT}/tests/fixtures/sample.sources.conf"
   assert_equal "${BAK_SOURCES_CONFIG_SOURCE[1]}" "/home/user"
   assert_equal "${BAK_SOURCES_CONFIG_DEPTH[1]}"  "0"
   assert_equal "${BAK_SOURCES_CONFIG_INC[1]}"    "0"
}

@test "source_config_read: parses third entry correctly" {
   source_config_read "${PROJECT_ROOT}/tests/fixtures/sample.sources.conf"
   assert_equal "${BAK_SOURCES_CONFIG_SOURCE[2]}" "/etc/app"
   assert_equal "${BAK_SOURCES_CONFIG_DEPTH[2]}"  "2"
   assert_equal "${BAK_SOURCES_CONFIG_INC[2]}"    "1"
}

@test "source_config_read: skips comment lines (only 3 data entries)" {
   source_config_read "${PROJECT_ROOT}/tests/fixtures/sample.sources.conf"
   assert_equal "${BAK_SOURCES_CONFIG_SOURCE[3]:-}" ""
}
