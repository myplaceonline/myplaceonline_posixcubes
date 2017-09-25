#!/bin/sh
# https://fedoraproject.org/wiki/PostgreSQL

if cube_set_file_contents "/etc/telegraf/telegraf.conf" "templates/telegraf.conf.template" ; then
  cube_service restart telegraf
fi

cube_service enable telegraf
cube_service start telegraf

cube_package install --nogpgcheck postgresql-server postgresql-contrib \
                                  postgresql-devel redhat-rpm-config \
                                  readline-devel openssl-devel libxslt-devel \
                                  pam-devel postgresql-static

cube_ensure_directory "/var/lib/pgsql/data/" 700 postgres postgres

cubevar_app_eth1=$(cube_interface_ipv4_address eth1)
if ! cube_has_role "database_backup" ; then
  cubevar_postgres_shared_buffers="$((($(cube_total_memory "mb")*4)/10))"
else
  cubevar_postgres_shared_buffers="$((($(cube_total_memory "mb")*15)/100))"
fi
if ! cube_has_role "database_backup" ; then
  cubevar_postgres_cache_size="$((($(cube_total_memory "mb")*75)/100))"
else
  cubevar_postgres_cache_size="$((($(cube_total_memory "mb")*25)/100))"
fi
  
if ! cube_has_role "database_backup" ; then
  if [ "$(ls -l /var/lib/pgsql/data/ | wc -l)" = "1" ]; then
    postgresql-setup --initdb --unit postgresql || cube_check_return
  fi
  
  cube_service enable postgresql
  cube_service start postgresql

  if cube_set_file_contents "/var/lib/pgsql/data/pg_hba.conf" "templates/pg_hba.conf.template" ; then
    chown postgres:postgres "/var/lib/pgsql/data/pg_hba.conf" || cube_check_return
    cube_service restart postgresql
  fi

  if cube_set_file_contents "/var/lib/pgsql/data/postgresql.replication.conf" "templates/postgresql.replication.conf" ; then
    chown postgres:postgres "/var/lib/pgsql/data/postgresql.replication.conf" || cube_check_return
  fi

  if cube_set_file_contents "/var/lib/pgsql/data/postgresql.conf" "templates/postgresql.conf.template" ; then
    chown postgres:postgres "/var/lib/pgsql/data/postgresql.conf" || cube_check_return
    cube_service restart postgresql
  fi
fi

cube_ensure_directory "/var/lib/pgsql/.ssh/" 700 postgres postgres

if cube_set_file_contents_string "/var/lib/pgsql/.ssh/authorized_keys" "${cubevar_app_keys_postgresql_public}" ; then
  chmod 700 "/var/lib/pgsql/.ssh/authorized_keys" || cube_check_return
  chown postgres:postgres "/var/lib/pgsql/.ssh/authorized_keys" || cube_check_return
fi

if cube_set_file_contents_string "/var/lib/pgsql/.ssh/id_rsa" "${cubevar_app_keys_postgresql}" ; then
  chmod 700 "/var/lib/pgsql/.ssh/id_rsa" || cube_check_return
  chown postgres:postgres "/var/lib/pgsql/.ssh/id_rsa" || cube_check_return
fi

# Recreate known_hosts
rm -f "/var/lib/pgsql/.ssh/known_hosts" 2>/dev/null
touch "/var/lib/pgsql/.ssh/known_hosts" || cube_check_return
chmod 700 "/var/lib/pgsql/.ssh/known_hosts" || cube_check_return
chown postgres:postgres "/var/lib/pgsql/.ssh/known_hosts" || cube_check_return

for cubevar_app_db_server in ${cubevar_app_db_servers}; do
  cubevar_app_server_internal=$(echo "${cubevar_app_db_server}" | sed 's/\./-internal./')
  if [ "${cubevar_app_db_server}" != "$(cube_hostname)" ]; then
    cubevar_app_keyscan="$(ssh-keyscan -t rsa,dsa "${cubevar_app_server_internal}")" || cube_check_return
    echo "${cubevar_app_keyscan}" | sort -u - /var/lib/pgsql/.ssh/known_hosts > /var/lib/pgsql/.ssh/tmp_hosts
    cat /var/lib/pgsql/.ssh/tmp_hosts > /var/lib/pgsql/.ssh/known_hosts
    rm /var/lib/pgsql/.ssh/tmp_hosts
    cube_echo "Registered known host for ${cubevar_app_server_internal}"
  fi
done

if ! cube_has_role "database_backup" ; then
  cubevar_app_sql_result="$(sudo -i -u postgres psql -tAc "SELECT * FROM pg_roles WHERE rolname='${cubevar_app_db_dbuser}'")" || cube_check_return
  if [ "$(echo "${cubevar_app_sql_result}" | grep "${cubevar_app_db_dbuser}" | wc -l)" != "1" ]; then
    sudo -i -u postgres psql -c "CREATE ROLE ${cubevar_app_db_dbuser} WITH LOGIN ENCRYPTED PASSWORD '${cubevar_app_passwords_postgresql_myplaceonline}' SUPERUSER;" || cube_check_return
  fi

  cubevar_app_sql_result="$(sudo -i -u postgres psql -tAc "SELECT datname FROM pg_database WHERE datname = '${cubevar_app_db_dbname}' and datistemplate = false;")" || cube_check_return
  if [ "$(echo "${cubevar_app_sql_result}" | grep "${cubevar_app_db_dbname}" | wc -l)" != "1" ]; then
    sudo -i -u postgres psql -c "CREATE DATABASE ${cubevar_app_db_dbname} WITH OWNER ${cubevar_app_db_dbuser};" || cube_check_return
  fi
fi

if ! cube_file_exists "/usr/bin/repmgr" ; then
  (
    cd /usr/local/src/ || cube_check_return
    wget https://github.com/2ndQuadrant/repmgr/archive/v3.3.tar.gz || cube_check_return
    tar xzvf v3.3.tar.gz || cube_check_return
    cd repmgr-3.3 || cube_check_return
    make USE_PGXS=1 install || cube_check_return
  ) || cube_check_return
fi

if ! cube_has_role "database_backup" ; then
  cubevar_app_sql_result="$(sudo -i -u postgres psql -tAc "SELECT * FROM pg_roles WHERE rolname='repmgr'")" || cube_check_return
  if [ "$(echo "${cubevar_app_sql_result}" | grep "repmgr" | wc -l)" != "1" ]; then
    sudo -i -u postgres psql -c "CREATE ROLE repmgr WITH SUPERUSER LOGIN;" || cube_check_return
  fi

  cubevar_app_sql_result="$(sudo -i -u postgres psql -tAc "SELECT datname FROM pg_database WHERE datname = 'repmgr' and datistemplate = false;")" || cube_check_return
  if [ "$(echo "${cubevar_app_sql_result}" | grep "repmgr" | wc -l)" != "1" ]; then
    sudo -i -u postgres psql -c "CREATE DATABASE repmgr WITH OWNER repmgr;" || cube_check_return
  fi
fi

cubevar_app_server_internal=$(echo "$(hostname)" | sed 's/\./-internal./')
cubevar_app_server_internal_cut=$(echo "$(hostname)" | sed 's/\..*$//')
cubevar_app_server_internal_number=$(echo "$(hostname)" | sed 's/.*\([0-9]\+\).*/\1/g')
if cube_set_file_contents "/etc/repmgr.conf" "templates/repmgr.conf.template" ; then
  chown postgres:postgres "/etc/repmgr.conf" || cube_check_return
fi

if ! cube_has_role "database_backup" ; then
  cubevar_app_sql_result="$(sudo -i -u postgres psql -d repmgr -tAc "SELECT table_schema, table_name FROM information_schema.tables where table_schema='repmgr_${cubevar_app_postgresql_replication_cluster}'")" || cube_check_return
  if [ "$(echo "${cubevar_app_sql_result}" | grep "repmgr" | wc -l)" = "0" ]; then
    sudo -i -u postgres /usr/bin/repmgr master register || cube_check_return
  fi
else
  if [ "$(ls -l /var/lib/pgsql/data/ | wc -l)" = "1" ]; then
    sudo -i -u postgres /usr/bin/repmgr -h ${cubevar_app_db_host} -U repmgr -d repmgr -D /var/lib/pgsql/data/ standby clone || cube_check_return
  fi

  if cube_set_file_contents "/var/lib/pgsql/data/postgresql.replication.conf" "templates/postgresql.replication.conf" ; then
    chown postgres:postgres "/var/lib/pgsql/data/postgresql.replication.conf" || cube_check_return
  fi

  if cube_set_file_contents "/var/lib/pgsql/data/postgresql.conf" "templates/postgresql.conf.template" ; then
    chown postgres:postgres "/var/lib/pgsql/data/postgresql.conf" || cube_check_return
    cube_service restart postgresql
  fi

  cube_service enable postgresql
  cube_service start postgresql

  cubevar_app_sql_result="$(sudo -i -u postgres psql -d repmgr -tAc "SELECT * FROM repmgr_${cubevar_app_postgresql_replication_cluster}.repl_nodes WHERE name='${cubevar_app_server_internal_cut}';")" || cube_check_return
  if [ "$(echo "${cubevar_app_sql_result}" | grep "${cubevar_app_server_internal_cut}" | wc -l)" = "0" ]; then
    sudo -i -u postgres /usr/bin/repmgr standby register || cube_check_return
  fi

  cube_ensure_directory "${cubevar_app_nfs_client_mount_backup}" 777
  
  if cube_set_file_contents_string "/var/spool/cron/root" "0 0 * * * rsync -avr /var/lib/remotenfs/ /var/lib/remotenfs_backup/ > /var/log/crontab.log 2>&1" ; then
    chmod 600 "/var/spool/cron/root" || cube_check_return
  fi
fi

cube_set_file_contents "/usr/lib/systemd/system/postgresql.service" "templates/postgresql.service"

true
