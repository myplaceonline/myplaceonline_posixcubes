#!/bin/sh

if [ "$(firewall-cmd --zone=public --list-ports | grep -c 80)" = "0" ]; then
  firewall-cmd --zone=public --add-port=80/tcp
  firewall-cmd --zone=public --permanent --add-port=80/tcp
  cube_echo "Opened firewall port for port 80"
fi

if [ "$(firewall-cmd --zone=public --list-ports | grep -c 443)" = "0" ]; then
  firewall-cmd --zone=public --add-port=443/tcp
  firewall-cmd --zone=public --permanent --add-port=443/tcp
  cube_echo "Opened firewall port for port 443"
fi

if [ "$(firewall-cmd --zone=public --list-ports | grep -c 9443)" = "0" ]; then
  firewall-cmd --zone=public --add-port=9443/tcp
  firewall-cmd --zone=public --permanent --add-port=9443/tcp
  cube_echo "Opened firewall port for port 9443"
fi

if cube_set_file_contents "/etc/telegraf/telegraf.conf" "templates/telegraf.conf.template" ; then
  cube_service restart telegraf
fi

cube_service enable telegraf
cube_service start telegraf

cube_package install haproxy socat nmap-ncat certbot nginx

cube_set_file_contents "/usr/share/nginx/html/maintenance.html" "templates/maintenance.html"

if cube_set_file_contents "/etc/nginx/nginx.conf" "templates/nginx.conf" ; then
  cube_service restart nginx
fi

cube_service enable nginx
cube_service start nginx

cube_ensure_directory /etc/haproxy/ssl/ 700 haproxy haproxy

# https://weakdh.org/sysadmin.html#haproxy
if ! cube_check_file_exists /etc/haproxy/ssl/myplaceonline.com.dh ; then
  (
    RANDFILE="/var/lib/haproxy/.rnd"
    openssl dhparam -out /etc/haproxy/ssl/myplaceonline.com.dh 2048 || cube_check_return
    chown haproxy /var/lib/haproxy/.rnd /etc/haproxy/ssl/myplaceonline.com.dh || cube_check_return
  )
fi

# See comments in haproxy.cfg.template
cubevar_app_haproxy_servers=""
for cubevar_app_web_server in ${cubevar_app_web_servers}; do
  cubevar_app_server_name=$(echo "${cubevar_app_web_server}" | sed 's/\..*$//g')
  cubevar_app_server_internal=$(echo "${cubevar_app_web_server}" | sed 's/\./-internal./')
  cube_read_heredoc <<HEREDOC; cubevar_app_line="${cube_read_heredoc_result}"
    #server  ${cubevar_app_server_name} ${cubevar_app_server_internal}:80 check
    server  ${cubevar_app_server_name} ${cubevar_app_server_internal}:80 check cookie ${cubevar_app_server_name}
HEREDOC
  cubevar_app_haproxy_servers=$(cube_append_str "${cubevar_app_haproxy_servers}" "${cubevar_app_line}" "${POSIXCUBE_NEWLINE}")
done

if cube_set_file_contents "/etc/haproxy/haproxy.cfg" "templates/haproxy.cfg.template" ; then
  chmod 644 /etc/haproxy/haproxy.cfg
  cube_service reload haproxy
fi

cube_service enable haproxy
cube_service start haproxy

if cube_set_file_contents "/etc/rsyslog.d/02-haproxy.conf" "templates/rsyslog_haproxy.conf" ; then
  cube_service restart rsyslog
fi

if ! cube_check_file_exists /etc/letsencrypt/live/ ; then
  /usr/bin/certbot --non-interactive --agree-tos --renew-by-default --email contact@myplaceonline.com --standalone --preferred-challenges http-01 --http-01-port 9999 certonly -d myplaceonline.com -d www.myplaceonline.com || cube_check_return
  cat /etc/letsencrypt/live/myplaceonline.com/{fullchain.pem,privkey.pem} > /etc/haproxy/ssl/myplaceonline.com.pem || cube_check_return
  cat /etc/haproxy/ssl/myplaceonline.com.dh >> /etc/haproxy/ssl/myplaceonline.com.pem || cube_check_return
fi

if cube_set_file_contents "/etc/cron.d/letsencrypt" "templates/crontab_letsencrypt" ; then
  chmod 600 /etc/cron.d/letsencrypt
fi
