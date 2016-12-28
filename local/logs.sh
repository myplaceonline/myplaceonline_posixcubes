#!/bin/sh
POSIXCUBE_SOURCED=true
. $(which posixcube.sh) source
POSIXCUBE_SOURCED=""

posixcube.sh -u root -h web*.myplaceonline.com "tail /var/log/messages"
