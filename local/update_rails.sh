#!/bin/sh
POSIXCUBE_SOURCED=true
. $(which posixcube.sh) source
POSIXCUBE_SOURCED=""

posixcube.sh -z web
