#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true
. $(which posixcube.sh) source
POSIXCUBE_SOURCED=""

LOCALDBHOST="$(echo "${cubevar_app_backup_host_db_public}" | sed 's/\./-internal./')"

ssh root@${cubevar_app_backup_host_db_public} "PGPASSWORD=\"${cubevar_app_passwords_postgresql_myplaceonline}\" psql -U myplaceonline -h ${LOCALDBHOST} -d myplaceonline_production -c \"${@}\""

popd
