#!/bin/sh

pushd "$(dirname "$0")/../"

read -e -p "Local output directory: " OUTPUTDIR

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

# Write to the root directory because /tmp is limited in some clouds
DBBACKUP=/myplaceonline_db_backup_$(date +"%Y%m%d_%H%M")_pgdump.sql

time ssh root@${cubevar_app_backup_node} "PGPASSWORD=${cubevar_app_passwords_postgresql_myplaceonline} PGSSLMODE=allow /usr/bin/pg_dump -U myplaceonline -h ${cubevar_app_db_host} -p 25060 -d myplaceonline_production -Fc > ${DBBACKUP}"

time scp root@${cubevar_app_backup_node}:${DBBACKUP} ${OUTPUTDIR} && \
  ssh root@${cubevar_app_backup_node} "rm -f ${DBBACKUP}"

popd
