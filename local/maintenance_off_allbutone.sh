#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

cubevar_app_redirect=$(curl --trace-ascii /dev/stdout -u "admin:${cubevar_app_passwords_haproxy_stats}" -d "s=web53" -d "action=ready" -d "b=#4" -w "%{redirect_url}" https://myplaceonline.com:9443/) || cube_check_return

if cube_string_contains "${cubevar_app_redirect}" "DONE" ; then
  curl https://myplaceonline.com/ || cube_check_return
  cube_echo "Successfully set maintenance to off"
else
  cube_throw "Invalid return code"
fi

popd
