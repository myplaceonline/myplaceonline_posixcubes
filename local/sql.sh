#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

ssh -t root@${cubevar_app_backup_node} "PGPASSWORD=\"${cubevar_app_passwords_postgresql_myplaceonline}\" psql -U myplaceonline -h ${cubevar_app_db_host} -p ${cubevar_app_db_port} -d ${cubevar_app_db_dbname} --set=sslmode=require"

popd
