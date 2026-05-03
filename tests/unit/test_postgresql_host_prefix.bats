#!/usr/bin/env bats
# Regression: postgresql_databases_backup filename uses
# ${BAK_DATE}-${BAK_POSTGRESQL_DATABASE_PREFIX}-${db}.sql

load '../test_helper'

setup() {
   load_main_lib
   TEST_TMP="${BATS_TMPDIR}/pg_host_prefix_$$"
   mkdir -p "$TEST_TMP"
   BAK_OUTPUT="${TEST_TMP}/out.txt"
   BAK_OUTPUT_EXTENDED="${TEST_TMP}/out_ext.txt"
   touch "$BAK_OUTPUT" "$BAK_OUTPUT_EXTENDED"

   BAK_POSTGRESQL_DATABASE_PATH="${TEST_TMP}/pg"
   mkdir -p "$BAK_POSTGRESQL_DATABASE_PATH"
   BAK_POSTGRESQL_DATABASE_ENABLED=1
   BAK_POSTGRESQL_DATABASE_WARNING_IF_DOWN=0
   BAK_POSTGRESQL_DATABASE_DATA_IF_DOWN=
   BAK_POSTGRESQL_DATABASE_ALLOW_ALL=1
   BAK_POSTGRESQL_DATABASE_ALLOW=()
   BAK_POSTGRESQL_DATABASE_DISALLOW=()
   BAK_POSTGRESQL_DATABASE_PREFIX="host"
   BAK_POSTGRESQL_DATABASE_LIST_CMD="echo mydb"
   BAK_POSTGRESQL_DATABASE_BACKUP_CMD="echo SQLDUMP"

   # postgresql_check uses POSTGRESQL_LSCLUSTER_BIN — stub returns "online"
   POSTGRESQL_LSCLUSTER_BIN="$(make_stub lsclusters 0 'online')"

   # Avoid heavyweight backup_process — stub it
   backup_process() { :; }
   export -f backup_process
}

teardown() { rm -rf "$TEST_TMP"; }

@test "postgresql_databases_backup: writes file with host prefix" {
   postgresql_databases_backup || true
   assert_file_exists "${BAK_POSTGRESQL_DATABASE_PATH}/${BAK_DATE}-host-mydb.sql"
}

@test "postgresql_databases_backup: prefix override appears in filename" {
   BAK_POSTGRESQL_DATABASE_PREFIX="primary"
   postgresql_databases_backup || true
   assert_file_exists "${BAK_POSTGRESQL_DATABASE_PATH}/${BAK_DATE}-primary-mydb.sql"
}
