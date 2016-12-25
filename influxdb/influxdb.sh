#!/bin/sh
# influx -host $HOST -database telegraf
#   show measurements
#   show tag keys
#   show field keys
#   show retention policies on telegraf
#   show series

# http://docs.influxdata.com/influxdb/v1.1/introduction/installation/
cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"
[influxdb]
name = InfluxDB Repository - RHEL 7Server
baseurl = https://repos.influxdata.com/rhel/7Server/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key
HEREDOC

cube_set_file_contents_string "/etc/yum.repos.d/influxdb.repo" "${cubevar_app_str}"

cube_package install influxdb

cubevar_app_eth1=$(cube_interface_ipv4_address eth1)
cubevar_app_server_internal=$(echo "$(hostname)" | sed 's/\./-internal./')

if cube_set_file_contents "/etc/influxdb/influxdb.conf" "templates/influxdb.conf.template" ; then
  cube_service restart influxdb
fi

cube_service enable influxdb

cubevar_influx_databases="$(influx -host ${cubevar_app_server_internal} -execute "show databases")"
if (echo "${cubevar_influx_databases}" | cube_stdin_contains "_internal") && ! (echo "${cubevar_influx_databases}" | cube_stdin_contains "telegraf") ; then
  influx -host ${cubevar_app_server_internal} -execute "CREATE DATABASE telegraf; CREATE USER influxadmin WITH PASSWORD '${cubevar_app_passwords_influxdb_admin}' WITH ALL PRIVILEGES"
  cube_echo "Created influxdb database and user"
fi
