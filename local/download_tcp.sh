#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

rm -rf tcpdumps 2>/dev/null
mkdir tcpdumps 2>/dev/null
pushd tcpdumps
for i in frontend3 web4 web12 db5 db6; do
  mkdir $i 2>/dev/null
  pushd $i
  ssh root@$i.myplaceonline.com 'cd /tmp; for i in tcpdump*; do cp -f $i /tmp/copied_$i; done'
  scp root@$i.myplaceonline.com:/tmp/copied_* .
  ssh root@$i.myplaceonline.com 'rm -f /tmp/copied_*'
  popd
done

popd
