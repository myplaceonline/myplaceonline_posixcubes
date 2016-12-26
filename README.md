# myplaceonline_posixcubes

Cubes that build a full Ruby on Rails stack with haproxy load balancer
(frontend), nginx+passenger Rails servers (web), postgresql database
(database) and more (elasticsearch, database backup, rsyslog server, etc.).

See execution parameters in [cubespecs.ini](cubespecs.ini)

Update all servers:

    for spec in database_backup database_primary web frontend; do posixcube.sh -z $spec || exit $?; done

## Add Web Server

Web server:

* Create Droplet
  * 2GB, SFO1
  * Private networking, IPv6
  * Select SSH Key
  * Hostname: webX.myplaceonline.com
* Networking > Floating IPs; Assign floating IP and copy it
* Networking > Domains > myplaceonline.com
  * Create A record for floating IP and short hostname

Get eth1 IP:

    SERVER_NUMBER=X
    ssh root@web${SERVER_NUMBER}.myplaceonline.com ip -4 -o addr | grep eth1 | awk '{print $4}' | sed 's/\/.*//g'

* Networking > Domains > myplaceonline.com
  * Create A record for eth1 IP and short hostname with -internal

Create web server:

    $(grep "^web=" cubespecs.ini | sed 's/^web=/posixcube.sh /g' | sed "s/\\-h web\\*/-h web${SERVER_NUMBER}/g")
    ssh root@web${SERVER_NUMBER}.myplaceonline.com reboot

Update frontend servers

    posixcube.sh -z frontend

## Destroy Web Server

* Destroy droplet
* Remove entry from ~/.ssh/known_hosts

Update frontend servers

    posixcube.sh -z frontend

* Remove DNS A names
