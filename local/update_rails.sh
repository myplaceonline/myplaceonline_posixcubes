#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true
. $(which posixcube.sh) source
POSIXCUBE_SOURCED=""

posixcube.sh -z web

popd
