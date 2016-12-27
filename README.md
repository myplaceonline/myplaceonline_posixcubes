# myplaceonline_posixcubes

Cubes that build a full Ruby on Rails stack with haproxy load balancer
(frontend), nginx+passenger Rails servers (web), postgresql database
(database) and more (elasticsearch, database backup, rsyslog server, etc.).

See execution parameters in [cubespecs.ini](cubespecs.ini)

Update all servers:

    for spec in database_backup database_primary web frontend; do posixcube.sh -z $spec || exit $?; done

## Create Web Server

Web server:

* Create Droplet
  * Fedora
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

Update frontend servers (to update available web servers list):

    posixcube.sh -z frontend

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
* Networking > Floating IPs; Assign floating IP and copy it
* Networking > Domains > myplaceonline.com
  * Create A record for floating IP and short hostname

Get eth1 IP:

    SERVER_NUMBER=X
    ssh root@frontend${SERVER_NUMBER}.myplaceonline.com ip -4 -o addr | grep eth1 | awk '{print $4}' | sed 's/\/.*//g'

* Networking > Domains > myplaceonline.com
  * Create A record for eth1 IP and short hostname with -internal

Create frontend server:

    $(grep "^frontend=" cubespecs.ini | sed 's/^frontend=/posixcube.sh /g' | sed "s/\\-h frontend\\*/-h frontend${SERVER_NUMBER}/g")
    ssh root@frontend${SERVER_NUMBER}.myplaceonline.com reboot

* Point floating IP of 138.68.192.106 to new frontend server

Update frontend server (to get TLS certificates):

    $(grep "^frontend=" cubespecs.ini | sed 's/^frontend=/posixcube.sh /g' | sed "s/\\-h frontend\\*/-h frontend${SERVER_NUMBER}/g")

