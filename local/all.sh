#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true
. $(which posixcube.sh) source
POSIXCUBE_SOURCED=""
posixcube.sh -s -u root -h *.myplaceonline.com "${@}"

popd
