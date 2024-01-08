#!/bin/sh

pushd "$(dirname "$0")/../"

read -e -p "Local output directory: " OUTPUTDIR

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

time ssh root@frontend7.myplaceonline.com "tar czvf - /usr/share/nginx/" > ${OUTPUTDIR}/myplaceonline_frontend_backup_$(date +"%Y%m%d_%H%M")_files.tar.gz

popd
