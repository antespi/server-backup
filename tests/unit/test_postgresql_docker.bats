#!/usr/bin/env bats
# Tests for PostgreSQL Docker backup functions

load '../test_helper'

setup() {
   load_main_lib
   TEST_TMP="${BATS_TMPDIR}/pg_docker_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/out.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/out_ext.txt"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"

   BAK_POSTGRESQL_DATABASE_PATH="${TEST_TMP}/pg"
   mkdir -p "$BAK_POSTGRESQL_DATABASE_PATH"
   BAK_POSTGRESQL_DATABASE_ALLOW_ALL=1
   BAK_POSTGRESQL_DATABASE_ALLOW=()
   BAK_POSTGRESQL_DATABASE_DISALLOW=()
   BAK_POSTGRESQL_DOCKER_ENABLED=1
   BAK_POSTGRESQL_DOCKER_CONTAINERS=()
   BAK_POSTGRESQL_DOCKER_WARNING_IF_DOWN=0

   backup_process() { :; }
   export -f backup_process
}

teardown() { rm -rf "$TEST_TMP"; }

# ---- postgresql_docker_check ----

@test "postgresql_docker_check: returns 0 when stub prints 'true'" {
   DOCKER_BIN="$(make_stub docker 0 'true')"
   run postgresql_docker_check pg1
   assert_success
}

@test "postgresql_docker_check: returns 1 when stub prints 'false'" {
   DOCKER_BIN="$(make_stub docker 0 'false')"
   run postgresql_docker_check pg1
   assert_failure
}

@test "postgresql_docker_check: returns 1 when docker exits non-zero" {
   DOCKER_BIN="$(make_stub docker 1 '')"
   run postgresql_docker_check pg1
   assert_failure
}

# ---- postgresql_docker_list_databases ----

@test "postgresql_docker_list_databases: parses psql --list output" {
   # psql -l -t -A -x produces "Name|<db>" lines among others
   local fixture="Name|app
Owner|postgres
Encoding|UTF8
Name|otherdb
Owner|postgres"
   DOCKER_BIN="$(make_stub docker 0 "$fixture")"
   run postgresql_docker_list_databases pg1
   assert_success
   assert_output --partial "app"
   assert_output --partial "otherdb"
}
