#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

echo ""
echo "CURRENT TIME: $(TZ=UTC date)"
echo ""

posixcube.sh -h root@${cubevar_app_syslog_serverhost_public} "tail -f /var/log/messages | grep -v systemd"

popd
