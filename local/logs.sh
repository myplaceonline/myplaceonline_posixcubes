#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

posixcube.sh -u root -h web*.myplaceonline.com "tail /var/log/messages; tail /var/www/html/myplaceonline/log/passenger.log"

posixcube.sh -u root -h frontend*.myplaceonline.com "tail /var/log/haproxy.log"

echo ""
echo "CURRENT TIME: $(TZ=UTC date)"
echo ""

popd
