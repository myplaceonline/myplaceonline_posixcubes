#!/bin/sh

# http://docs.grafana.org/installation/rpm/
cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"
[grafana]
name=grafana
baseurl=https://packagecloud.io/grafana/stable/el/6/$basearch
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
HEREDOC

cube_set_file_contents_string "/etc/yum.repos.d/grafana.repo" "${cubevar_app_str}"

cube_package install grafana fontconfig freetype* urw-fonts certbot

if cube_set_file_contents "/usr/lib/systemd/system/grafana-server.service" "templates/grafana-server.service" ; then
  cube_service daemon-reload
fi

cube_ensure_directory "/var/lib/grafana/dashboards/" 755 grafana grafana
for cubevar_grafana_dashboard in dashboards/*; do
  cubevar_grafana_dashboard="$(basename ${cubevar_grafana_dashboard})"
  if cube_set_file_contents "/var/lib/grafana/dashboards/${cubevar_grafana_dashboard}" "dashboards/${cubevar_grafana_dashboard}" ; then
    chown grafana:grafana "/var/lib/grafana/dashboards/${cubevar_grafana_dashboard}"
  fi
done

cubevar_app_grafana_nodename="$(cube_hostname "true")"
cubevar_app_eth1=$(cube_interface_ipv4_address eth1)
cubevar_app_server_internal=$(echo "$(hostname)" | sed 's/\./-internal./')

if [ "$(firewall-cmd --zone=public --list-ports | grep -c 443)" = "0" ]; then
  firewall-cmd --zone=public --add-port=443/tcp
  firewall-cmd --zone=public --permanent --add-port=443/tcp
  cube_echo "Opened firewall port for port 443"
fi

if ! cube_check_file_exists "/etc/letsencrypt/live/${cubevar_app_grafana_host}/fullchain.pem" ; then
  certbot --non-interactive --agree-tos --renew-by-default --email contact@myplaceonline.com --standalone certonly -d ${cubevar_app_grafana_host} || cube_check_return
  cp "/etc/letsencrypt/live/${cubevar_app_grafana_host}/fullchain.pem" "/etc/letsencrypt/live/${cubevar_app_grafana_host}/privkey.pem" /etc/grafana/ || cube_check_return
  chown ${USER}:grafana /etc/grafana/*pem || cube_check_return
fi
  
if cube_set_file_contents "/etc/grafana/grafana.ini" "templates/grafana.ini.template" ; then
  cube_service restart grafana-server
fi
 
cube_service enable grafana-server
cube_service start grafana-server

if cube_set_file_contents "/etc/cron.d/grafana" "templates/crontab_grafana.template" ; then
  chmod 600 /etc/cron.d/grafana
fi

cubevar_grafana_datasources="$(curl -s -u "admin:${cubevar_app_passwords_grafana_admin}" https://${cubevar_app_grafana_host}/api/datasources)" || cube_check_return

if [ "${cubevar_grafana_datasources}" = "[]" ]; then
  cube_echo "Creating grafana data source"
  curl -s -u "admin:${cubevar_app_passwords_grafana_admin}" https://${cubevar_app_grafana_host}/api/datasources --data-urlencode "access=proxy" --data-urlencode "database=telegraf" --data-urlencode "name=mydb" --data-urlencode "password=${cubevar_app_passwords_influxdb_admin}" --data-urlencode "type=influxdb" --data-urlencode "url=http://db2-internal.myplaceonline.com:8086/" --data-urlencode "user=influxadmin"
fi
