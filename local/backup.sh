#!/bin/sh

pushd "$(dirname "$0")/../"

echo -n "Encrypted file password: "
read -s ENCRYPTED_FILE_PASSWORD
echo
echo -n "Repeat Encrypted file password: "
read -s ENCRYPTED_FILE_PASSWORD2
echo
if [ "${ENCRYPTED_FILE_PASSWORD}" != "${ENCRYPTED_FILE_PASSWORD2}" ]; then
  echo "Passwords don't match! Exiting"
  exit 1
fi
read -e -p "Local output directory: " OUTPUTDIR

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

# Write to the root directory because /tmp is limited in some clouds
OUTPUTFILE=/myplaceonline_backup_$(date +"%Y%m%d_%H%M")_pgdump.sql
LARGEFILES=/myplaceonline_backup_$(date +"%Y%m%d_%H%M")_files.tar.gz
PRIMARYLARGEFILES=/myplaceonline_primary_backup_$(date +"%Y%m%d_%H%M")_files.tar.gz
LOCALDBHOST="$(echo "${cubevar_app_backup_host_db_public}" | sed 's/\./-internal./')"

time ssh root@${cubevar_app_primary_host_db_public} "tar czvf ${PRIMARYLARGEFILES} /var/lib/remotenfs/" && \
  scp root@${cubevar_app_primary_host_db_public}:${PRIMARYLARGEFILES} ${OUTPUTDIR} && \
  ssh root@${cubevar_app_primary_host_db_public} "rm -f ${PRIMARYLARGEFILES};"

# Stop elasticsearch temporarily because otherwise we might run out of memory
time ssh root@${cubevar_app_backup_host_db_public} "systemctl stop elasticsearch; systemctl stop influxd; sudo -i -u postgres psql myplaceonline_production -c 'select pg_xlog_replay_pause();' && sudo -i -u postgres psql myplaceonline_production -c 'select  pg_is_xlog_replay_paused();' && PGPASSWORD=${cubevar_app_passwords_postgresql_myplaceonline} /usr/bin/pg_dump -U myplaceonline -h ${LOCALDBHOST} -d myplaceonline_production -Fc > ${OUTPUTFILE} && sudo -i -u postgres psql myplaceonline_production -c 'select pg_xlog_replay_resume();'; systemctl start elasticsearch; systemctl start influxd;" && \
  scp root@${cubevar_app_backup_host_db_public}:${OUTPUTFILE} ${OUTPUTDIR} && \
  ssh root@${cubevar_app_backup_host_db_public} "rm -f ${OUTPUTFILE}" && \
  ssh root@${cubevar_app_backup_host_db_public} "tar czvf ${LARGEFILES} /var/lib/remotenfs/" && \
  scp root@${cubevar_app_backup_host_db_public}:${LARGEFILES} ${OUTPUTDIR} && \
  ssh root@${cubevar_app_backup_host_db_public} "rm -f ${LARGEFILES};" && \
  echo "Done. To encrypt:"
  echo "gpg --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo sha512 -o ${OUTPUTFILE#/}.pgp --symmetric ${OUTPUTFILE#/}; rm ${OUTPUTFILE#/};"
  echo "gpg --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo sha512 -o ${LARGEFILES#/}.pgp --symmetric ${LARGEFILES#/}; rm ${LARGEFILES#/}"
  echo "gpg --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo sha512 -o ${PRIMARYLARGEFILES#/}.pgp --symmetric ${PRIMARYLARGEFILES#/}; rm ${PRIMARYLARGEFILES#/}"

popd
