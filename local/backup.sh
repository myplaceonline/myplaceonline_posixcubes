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

POSIXCUBE_SOURCED=true
. $(which posixcube.sh) source
POSIXCUBE_SOURCED=""

# Write to the root directory because /tmp is limited in some clouds
OUTPUTFILE=/pgdump_myplaceonline_$(date +"%Y%m%d_%H%M").sql
LARGEFILES=/largefiles_myplaceonline_$(date +"%Y%m%d_%H%M").tar.gz
LOCALDBHOST="$(echo "${cubevar_app_backup_host_db_public}" | sed 's/\./-internal./')"

ssh root@${cubevar_app_backup_host_db_public} "sudo -i -u postgres psql myplaceonline_production -c 'select pg_xlog_replay_pause();' && sudo -i -u postgres psql myplaceonline_production -c 'select  pg_is_xlog_replay_paused();' && PGPASSWORD=${cubevar_app_passwords_postgresql_myplaceonline} /usr/bin/pg_dump -U myplaceonline -h ${LOCALDBHOST} -d myplaceonline_production -Fc > ${OUTPUTFILE} && sudo -i -u postgres psql myplaceonline_production -c 'select pg_xlog_replay_resume();'  && echo '${ENCRYPTED_FILE_PASSWORD}' | /usr/bin/gpg --batch --no-tty --passphrase-fd 0 --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo sha512 -o ${OUTPUTFILE}.pgp --symmetric ${OUTPUTFILE}; rm ${OUTPUTFILE};" && \
scp root@${cubevar_app_backup_host_db_public}:${OUTPUTFILE}.pgp ${OUTPUTDIR} && \
ssh root@${cubevar_app_backup_host_db_public} "rm -f ${OUTPUTFILE}.pgp" && \
ssh root@${cubevar_app_backup_host_db_public} "tar czvf ${LARGEFILES} /var/lib/remotenfs_backup/ && echo '${ENCRYPTED_FILE_PASSWORD}' | /usr/bin/gpg --batch --no-tty --passphrase-fd 0 --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo sha512 -o ${LARGEFILES}.pgp --symmetric ${LARGEFILES}; rm ${LARGEFILES}" &&
scp root@${cubevar_app_backup_host_db_public}:${LARGEFILES}.pgp ${OUTPUTDIR} && \
ssh root@${cubevar_app_backup_host_db_public} "rm -f ${LARGEFILES}.pgp" && \
echo "Done"

popd
