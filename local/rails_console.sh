#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

posixcube.sh -u root -h ${cubevar_app_primary_host_web_public} "systemctl stop nginx && cd /var/www/html/myplaceonline/; RAILS_ENV=production FTS_TARGET=${cubevar_app_full_text_search_target} BUNDLE_GEMFILE=${cubevar_app_rails_gemfile} bin/rails console; systemctl start nginx;"

popd
