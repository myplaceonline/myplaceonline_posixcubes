#!/bin/sh

pushd "$(dirname "$0")/../"

read -e -p "Local output directory: " OUTPUTDIR

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

echo "Backing up from ${cubevar_app_email_host}..."

time ssh root@${cubevar_app_email_host} "tar czvf - /mnt/mailvolume/" > ${OUTPUTDIR}/myplaceonline_email_backup_$(date +"%Y%m%d_%H%M")_files.tar.gz

popd
