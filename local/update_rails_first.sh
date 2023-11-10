#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

#export POSIXCUBE_COLORS=true

posixcube.sh -R -u root -h web58.myplaceonline.com -O cubevar_app_servers=*.myplaceonline.com -O cubevar_app_web_servers=web* -U firewall_whitelist -U nfs_client -c web_begin -c core_begin -c postfix_sender -c web -c core_end

popd
