# myplaceonline_posixcubes

Cubes that build a full Ruby on Rails stack with haproxy load balancer
(frontend), nginx+passenger Rails servers (web), postgresql database
(database) and more (elasticsearch, database backup, rsyslog server, etc.).

See execution parameters in [cubespecs.ini](cubespecs.ini)

Update all servers:

    for spec in database_backup database_primary web frontend; do posixcube.sh -z $spec || exit $?; done

