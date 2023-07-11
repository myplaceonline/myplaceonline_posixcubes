# myplaceonline_posixcubes

Cubes that build a full Ruby on Rails stack with haproxy load balancer
(frontend), nginx+passenger Rails servers (web), postgresql database
(database) and more (elasticsearch, database backup, rsyslog server, etc.)
using [posixcube.sh](https://github.com/myplaceonline/posixcube).

See execution parameters in [cubespecs.ini](cubespecs.ini)

## Create Web Server

Web server:

* Create Droplet
  * Fedora on SFO3
  * Basic, 8GB/4CPU
  * Advanced Options } IPv6
  * Select SSH Key
  * Hostname: webX.myplaceonline.com
* Add to database trusted sources
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

Restart the server:

    ssh root@web${SERVER_NUMBER}.myplaceonline.com reboot

Wait about 5 minutes for the server to start up

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
  * 1GB, SFO3
  * Advanced Options } IPv6
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

Create frontend server:

    $(grep "^frontend=" cubespecs.ini | sed 's/^frontend=/posixcube.sh /g' | sed "s/\\-h frontend\\*/-h frontend${SERVER_NUMBER}/g")

There will be certbot errors. Reboot.

rsync any necessary static files:

    rsync -azP $DIR/ root@frontend${SERVER_NUMBER}.myplaceonline.com:/usr/share/nginx/$DIR

    ssh root@frontend${SERVER_NUMBER}.myplaceonline.com reboot

Run again:

    $(grep "^frontend=" cubespecs.ini | sed 's/^frontend=/posixcube.sh /g' | sed "s/\\-h frontend\\*/-h frontend${SERVER_NUMBER}/g")

Point floating IP of 143.198.245.8 to new frontend server

## Backup Database

    # The output file is compressed
    sudo -i -u postgres pg_dump -U myplaceonline -d myplaceonline_production -Fc > /tmp/pgdump_myplaceonline_`date +"%Y%m%d_%H%M"`.sql.bin

## Restore Database

    sudo -i -u postgres pg_restore -U myplaceonline -d myplaceonline_production /tmp/pgdump_myplaceonline*.sql.bin

## Architecture Notes

* Droplets have a public network (eth0) and a private network (eth1). Both are behind firewalls with eth0 in the
  public zone and eth1 in the trusted zone. The trusted zone has a whitelist of IP addresses. All non-public services
  should bind on the eth1 interface. Even though they could instead bind on every interface and just use the firewall
  to block access, there could be a case where for example, we whitelist an IP on the public interface which gets
  too much access to internal services.

## spamassassin

1. Add [rule](https://cwiki.apache.org/confluence/display/spamassassin/WritingRules) at the top of `/etc/mail/spamassassin/local.cf`; for example:
   ```
   body LOCAL_BLACKLIST1_RULE /Some spammy subject/
   score LOCAL_BLACKLIST1_RULE 10
   describe LOCAL_BLACKLIST1_RULE BLACKLIST1
   ```
1. Restart `spampd` and `opensmtpd`:
   ```
   systemctl restart spampd
   systemctl restart opensmtpd
   ```
1. Test sending an email that matches and make sure it goes into the Spam folder.
