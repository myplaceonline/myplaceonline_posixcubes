#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

posixcube.sh -u root -h ${cubevar_app_primary_host_web_public} "cd /var/www/html/myplaceonline/; RAILS_ENV=production FTS_TARGET=${cubevar_app_full_text_search_target} bin/rails console"

popd
