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
DBBACKUP=/myplaceonline_db_backup_$(date +"%Y%m%d_%H%M")_pgdump.sql
LARGEFILES=/myplaceonline_largefiles_backup_$(date +"%Y%m%d_%H%M")_files.tar.gz

time ssh root@${cubevar_app_backup_node} "PGPASSWORD=${cubevar_app_passwords_postgresql_myplaceonline} PGSSLMODE=allow /usr/bin/pg_dump -U myplaceonline -h ${cubevar_app_db_host} -p 25060 -d myplaceonline_production -Fc > ${DBBACKUP}"

time scp root@${cubevar_app_backup_node}:${DBBACKUP} ${OUTPUTDIR} && \
  ssh root@${cubevar_app_backup_node} "rm -f ${DBBACKUP}" && \
  ssh root@${cubevar_app_backup_node} "tar czvf ${LARGEFILES} /var/lib/remotenfs/" && \
  scp root@${cubevar_app_backup_node}:${LARGEFILES} ${OUTPUTDIR} && \
  ssh root@${cubevar_app_backup_node} "rm -f ${LARGEFILES};" && \
  echo "Done. To encrypt:"
  echo "gpg --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo sha512 -o ${DBBACKUP#/}.pgp --symmetric ${DBBACKUP#/}; rm ${DBBACKUP#/};"
  echo "gpg --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo sha512 -o ${LARGEFILES#/}.pgp --symmetric ${LARGEFILES#/}; rm ${LARGEFILES#/}"

popd
