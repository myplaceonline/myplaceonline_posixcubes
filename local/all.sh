#!/bin/sh
POSIXCUBE_SOURCED=true
. $(which posixcube.sh) source
POSIXCUBE_SOURCED=""
posixcube.sh -s -u root -h *.myplaceonline.com "${@}"
