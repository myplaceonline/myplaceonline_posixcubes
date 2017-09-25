# myplaceonline_posixcubes

Cubes that build a full Ruby on Rails stack with haproxy load balancer
(frontend), nginx+passenger Rails servers (web), postgresql database
(database) and more (elasticsearch, database backup, rsyslog server, etc.)
using [posixcube.sh](https://github.com/myplaceonline/posixcube).

See execution parameters in [cubespecs.ini](cubespecs.ini)

Update all servers:

    for spec in database_backup database_primary web frontend; do posixcube.sh -z $spec || break; done

## Create Web Server

Web server:

* Create Droplet
  * Ubuntu or Fedora
  * 2GB, SFO1
  * Private networking, IPv6
  * Select SSH Key
  * Hostname: webX.myplaceonline.com
* Networking > Domains > myplaceonline.com
  * Create A record for short hostname and droplet

Get eth1 IP:

    SERVER_NUMBER=X
    ssh root@web${SERVER_NUMBER}.myplaceonline.com ip -4 -o addr | grep eth1 | awk '{print $4}' | sed 's/\/.*//g'

* Networking > Domains > myplaceonline.com
  * Create A record for eth1 IP and short hostname with -internal

Add server to the other servers' whitelist:

    posixcube.sh -z firewall_whitelist

Create web server:

    $(grep "^web=" cubespecs.ini | sed 's/^web=/posixcube.sh /g' | sed "s/\\-h web\\*/-h web${SERVER_NUMBER}/g")
    ssh root@web${SERVER_NUMBER}.myplaceonline.com reboot

Update frontend servers (to update available web servers list):

    posixcube.sh -z frontend

Update web servers (to update trusted client list):

    posixcube.sh -z web

## Destroy Web Server

* Remove entry from ~/.ssh/known_hosts

Update frontend servers (to update available web servers list):

    posixcube.sh -z frontend

* Destroy droplet
* Remove DNS A names

Update web servers (to update trusted client list):

    posixcube.sh -z web

## Create Frontend Server

* Create Droplet
  * Fedora
  * 512MB, SFO1
  * Private networking, IPv6
  * Select SSH Key
  * Hostname: frontendX.myplaceonline.com
* Networking > Domains > myplaceonline.com
  * Create A record for public IP and short hostname

Get eth1 IP:

    SERVER_NUMBER=X
    ssh root@frontend${SERVER_NUMBER}.myplaceonline.com ip -4 -o addr | grep eth1 | awk '{print $4}' | sed 's/\/.*//g'

* Networking > Domains > myplaceonline.com
  * Create A record for eth1 IP and short hostname with -internal

Add server to the other servers' whitelist:

    posixcube.sh -z firewall_whitelist

Point floating IP of 138.68.192.106 to new frontend server

Create frontend server:

    $(grep "^frontend=" cubespecs.ini | sed 's/^frontend=/posixcube.sh /g' | sed "s/\\-h frontend\\*/-h frontend${SERVER_NUMBER}/g")
    # There will be certbot errors. Reboot and run again:
    ssh root@frontend${SERVER_NUMBER}.myplaceonline.com reboot

Update frontend server (to get TLS certificates):

    $(grep "^frontend=" cubespecs.ini | sed 's/^frontend=/posixcube.sh /g' | sed "s/\\-h frontend\\*/-h frontend${SERVER_NUMBER}/g")

## Create Primary Database Server

* Create Droplet
  * Fedora
  * 2GB, SFO1
  * Private networking, IPv6
  * Select SSH Key
  * Hostname: dbX.myplaceonline.com
* Networking > Domains > myplaceonline.com
  * Create A record for public IP and short hostname

Get eth1 IP:

    SERVER_NUMBER=X
    ssh root@db${SERVER_NUMBER}.myplaceonline.com ip -4 -o addr | grep eth1 | awk '{print $4}' | sed 's/\/.*//g'

* Networking > Domains > myplaceonline.com
  * Create A record for eth1 IP and short hostname with -internal

Add server to the other servers' whitelist:

    posixcube.sh -z firewall_whitelist

Create primary database server:

    # If creating while older DB servers exist, echo without the $() and replace the -O options with an explicit set
    $(grep "^database_primary=" cubespecs.ini | sed 's/^database_primary=/posixcube.sh /g' | sed "s/\\-h db./-h db${SERVER_NUMBER}/g")

## Destroy Primary Database Server

Remember to copy over the NFS share

## Create Backup Database Server

* Create Droplet
  * Fedora
  * 2GB, SFO1
  * Private networking, IPv6
  * Select SSH Key
  * Hostname: dbX.myplaceonline.com
* Networking > Domains > myplaceonline.com
  * Create A record for public IP and short hostname

Get eth1 IP:

    SERVER_NUMBER=X
    ssh root@db${SERVER_NUMBER}.myplaceonline.com ip -4 -o addr | grep eth1 | awk '{print $4}' | sed 's/\/.*//g'

* Networking > Domains > myplaceonline.com
  * Create A record for eth1 IP and short hostname with -internal

Add server to the other servers' whitelist:

    posixcube.sh -z firewall_whitelist

Create backup database server:

    # If creating while older DB servers exist, echo without the $() and replace the -O options with an explicit set
    $(grep "^database_backup=" cubespecs.ini | sed 's/^database_backup=/posixcube.sh /g' | sed "s/\\-h db./-h db${SERVER_NUMBER}/g")

## Check Replication Status

    # On the master database
    posixcube.sh -u root -h db5.myplaceonline.com "sudo -i -u postgres psql -xc 'SELECT * FROM pg_stat_replication;'"

## Quiesce Database Activity

    posixcube.sh -u root -h web*.myplaceonline.com "cube_service stop nginx; cube_service stop myplaceonline-delayedjobs; cube_service stop crond;"

## Backup Database

    # The output file is compressed
    sudo -i -u postgres pg_dump -U myplaceonline -d myplaceonline_production -Fc > /tmp/pgdump_myplaceonline_`date +"%Y%m%d_%H%M"`.sql.bin

## Restore Database

    sudo -i -u postgres pg_restore -U myplaceonline -d myplaceonline_production /tmp/pgdump_myplaceonline*.sql.bin

## Promote Backup Database

    # https://github.com/2ndQuadrant/repmgr#promoting-a-standby-server-with-repmgr
    repmgr -f /etc/repmgr.conf standby promote

## Architecture Notes

* Droplets have a public network (eth0) and a private network (eth1). Both are behind firewalls with eth0 in the
  public zone and eth1 in the trusted zone. The trusted zone has a whitelist of IP addresses. All non-public services
  should bind on the eth1 interface. Even though they could instead bind on every interface and just use the firewall
  to block access, there could be a case where for example, we whitelist an IP on the public interface which gets
  too much access to internal services.
