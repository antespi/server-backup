#!/usr/bin/env bash
# Shared setup for all bats tests.
# Source this file at the top of each .bats file:
#   load '../test_helper'

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

source "$PROJECT_ROOT/tests/libs/bats-support/load.bash"
source "$PROJECT_ROOT/tests/libs/bats-assert/load.bash"
source "$PROJECT_ROOT/tests/libs/bats-file/load.bash"

# Source lib/main.sh with a safe set of prerequisite variables.
# Call this inside setup() for any test that needs main.sh functions.
load_main_lib() {
   export BAK_PATH="$PROJECT_ROOT"
   export BAK_DATA_PATH="${BATS_TMPDIR}/bak_data_$$"
   export BAK_LOG_DIR="log"
   export BAK_CONFIG_DIR="config"
   export BAK_DATE="2026-01-01_120000"
   export BAK_ENCRYPT=0
   export BAK_ENCRYPT_ALG="-aes-256-cbc"
   export BAK_ENCRYPT_KEY_FILE="$BAK_PATH/$BAK_CONFIG_DIR/enc.key"

   # shellcheck source=../lib/main.sh
   source "$PROJECT_ROOT/lib/main.sh"

   # Redirect all log output to a temp file so tests can inspect it.
   export BAK_OUTPUT="${BATS_TMPDIR}/bak_output_$$.txt"
   export BAK_OUTPUT_EXTENDED="${BATS_TMPDIR}/bak_output_ext_$$.txt"
   export BAK_NULL_OUTPUT="/dev/null"

   # Override _BIN variables to safe no-op stubs where needed.
   # Tests that require real commands should restore these explicitly.
   export ECHO_BIN="echo"
   export RM_BIN="rm -rf"
   export MKDIR_BIN="mkdir -p"
   export FIND_BIN="find"
   export GREP_BIN="grep"
   export CUT_BIN="cut"
   export DATE_BIN="date"

   # PostgreSQL prefix (host) + docker defaults so postgresql_databases_backup
   # and postgresql_docker_databases_backup can be exercised by tests.
   export BAK_POSTGRESQL_DATABASE_PREFIX="host"
   export BAK_POSTGRESQL_DOCKER_ENABLED=0
   export BAK_POSTGRESQL_DOCKER_CONTAINERS=()
   export BAK_POSTGRESQL_DOCKER_WARNING_IF_DOWN=0
   export BAK_POSTGRESQL_DOCKER_USER="postgres"
   export DOCKER_BIN="docker"
}

# Read $BAK_OUTPUT content for assertion.
bak_output_content() {
   cat "$BAK_OUTPUT" 2>/dev/null || true
}

# Create a temporary stub script and print its path.
# Usage: make_stub <name> [exit_code] [stdout_line]
# Example: BAK_S3_PUT_BIN="$(make_stub s3put 0)"
#          BAK_S3_AUTOCHECK_BIN="$(make_stub s3check 0 'ERROR: no bucket')"
make_stub() {
   local name="$1" exit_code="${2:-0}" output="${3:-}"
   local stub="${BATS_TMPDIR}/stub_${name}_$$.sh"
   {
      echo "#!/bin/bash"
      [ -n "$output" ] && printf 'echo "%s"\n' "$output"
      echo "exit $exit_code"
   } > "$stub"
   chmod +x "$stub"
   echo "$stub"
}
