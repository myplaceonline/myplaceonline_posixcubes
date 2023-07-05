#!/bin/sh

pushd "$(dirname "$0")/../"

read -e -p "Local output directory: " OUTPUTDIR

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

# Write to the root directory because /tmp is limited in some clouds
EMAILFILES=/myplaceonline_email_backup_$(date +"%Y%m%d_%H%M")_files.tar.gz

time ssh root@${cubevar_app_email_host} "tar czvf ${EMAILFILES} /mnt/mailvolume/"

scp root@${cubevar_app_email_host}:${EMAILFILES} ${OUTPUTDIR} && \
  ssh root@${cubevar_app_email_host} "rm -f ${EMAILFILES};"

popd
