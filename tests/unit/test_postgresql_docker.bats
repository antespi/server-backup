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

# ---- postgresql_docker_dump ----

@test "postgresql_docker_dump: passes container and db to docker exec, prints SQL" {
   # Stub records its argv to a sentinel file and prints the dump body.
   local args_file="${TEST_TMP}/docker_args"
   local stub="${TEST_TMP}/docker_stub.sh"
   cat > "$stub" <<EOS
#!/bin/bash
echo "\$@" > "$args_file"
echo "-- SQL DUMP --"
EOS
   chmod +x "$stub"
   DOCKER_BIN="$stub"

   run postgresql_docker_dump pg1 mydb
   assert_success
   assert_output --partial "-- SQL DUMP --"

   run cat "$args_file"
   assert_output "exec -u postgres pg1 pg_dump -Fp mydb"
}

# ---- postgresql_docker_databases_backup ----

@test "postgresql_docker_databases_backup: ENABLED=0 short-circuits" {
   BAK_POSTGRESQL_DOCKER_ENABLED=0
   BAK_POSTGRESQL_DOCKER_CONTAINERS=("pg1")
   run postgresql_docker_databases_backup
   assert_success
   run grep "Disabled by configuration" "$BAK_OUTPUT"
   assert_success
}

@test "postgresql_docker_databases_backup: empty container list returns 0" {
   BAK_POSTGRESQL_DOCKER_ENABLED=1
   BAK_POSTGRESQL_DOCKER_CONTAINERS=()
   run postgresql_docker_databases_backup
   assert_success
}

@test "postgresql_docker_databases_backup: down + WARNING_IF_DOWN=1 returns 0 with warning" {
   BAK_POSTGRESQL_DOCKER_ENABLED=1
   BAK_POSTGRESQL_DOCKER_CONTAINERS=("pg1")
   BAK_POSTGRESQL_DOCKER_WARNING_IF_DOWN=1
   DOCKER_BIN="$(make_stub docker 0 'false')"
   run postgresql_docker_databases_backup
   assert_success
   run grep "WARNING - Container 'pg1' is not running" "$BAK_OUTPUT"
   assert_success
}

@test "postgresql_docker_databases_backup: down + WARNING_IF_DOWN=0 returns 1 with FAIL" {
   BAK_POSTGRESQL_DOCKER_ENABLED=1
   BAK_POSTGRESQL_DOCKER_CONTAINERS=("pg1")
   BAK_POSTGRESQL_DOCKER_WARNING_IF_DOWN=0
   DOCKER_BIN="$(make_stub docker 0 'false')"
   run postgresql_docker_databases_backup
   assert_failure
   run grep "FAIL - Container 'pg1' is not running" "$BAK_OUTPUT"
   assert_success
}
