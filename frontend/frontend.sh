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

# if cube_set_file_contents "/etc/telegraf/telegraf.conf" "templates/telegraf.conf.template" ; then
#   cube_service restart telegraf
# fi
# 
# cube_service enable telegraf
# cube_service start telegraf

cube_package install haproxy socat nmap-ncat certbot nginx fcgiwrap httpd

cube_set_file_contents "/usr/share/nginx/html/maintenance.html" "templates/maintenance.html"

cube_ensure_directory "/usr/share/nginx/html/frontend"

cube_set_file_contents_string "/usr/share/nginx/html/frontend/index.html" "Hello World"

if cube_set_file_contents "/usr/lib/systemd/system/fcgiwrap.service" "templates/fcgiwrap.service" ; then
  cube_set_file_contents "/usr/lib/systemd/system/fcgiwrap.socket" "templates/fcgiwrap.socket"
  cube_service daemon-reload
  cube_service enable fcgiwrap
  cube_service start fcgiwrap
fi

cube_ensure_directory "/var/www/" "a+rx"
cube_ensure_directory "/var/www/cgi-bin/" "a+rx"
cube_ensure_directory "/var/www/cgi-bin/api/" "a+rx"

if cube_set_file_contents "/var/www/cgi-bin/api/write_marker" "templates/writer_marker.template" ; then
  chmod a+rx /var/www/cgi-bin/api/write_marker
fi

if cube_set_file_contents "/etc/nginx/nginx.conf" "templates/nginx.conf.template" ; then
  cube_service restart nginx
fi

cube_ensure_directory /etc/haproxy/ssl/ 700 haproxy haproxy
cube_ensure_directory /etc/haproxy/ssl/dh/ 700 haproxy haproxy
cube_ensure_file /etc/haproxy/haproxy_ssl.cfg 700 haproxy haproxy

# Use multiple `-f` options for HAProxy for the SSL config file:
# http://permalink.gmane.org/gmane.comp.web.haproxy/5899
if cube_set_file_contents "/usr/lib/systemd/system/haproxy.service" "templates/haproxy.service" ; then
  cube_service daemon-reload
fi

cube_service enable nginx
cube_service start nginx

cubevar_app_letsencrypt_tls_domain=""
for cubevar_app_tls_domain in ${cubevar_app_tls_domains}; do
  cubevar_app_letsencrypt_tls_domain="${cubevar_app_letsencrypt_tls_domain} -d ${cubevar_app_tls_domain} -d *.${cubevar_app_tls_domain}"

  # https://weakdh.org/sysadmin.html#haproxy
  if ! cube_file_exists /etc/haproxy/ssl/dh/${cubevar_app_tls_domain}.dh ; then
    (
      RANDFILE="/var/lib/haproxy/.rnd"
      touch "${RANDFILE}" || cube_check_return
      chown haproxy:haproxy "${RANDFILE}" || cube_check_return
      openssl dhparam -out /etc/haproxy/ssl/dh/${cubevar_app_tls_domain}.dh 2048 || cube_check_return
      chown haproxy:haproxy /etc/haproxy/ssl/dh/${cubevar_app_tls_domain}.dh || cube_check_return
    )
  fi
done

# See comments in haproxy.cfg.template
cubevar_app_haproxy_servers=""
cubevar_app_haproxy_servers_bypass=""

for cubevar_app_web_server in ${cubevar_app_web_servers}; do
  cubevar_app_server_name=$(echo "${cubevar_app_web_server}" | sed 's/\..*$//g')
  cubevar_app_server_internal=$(echo "${cubevar_app_web_server}" | sed 's/\./-internal./')
  
  cube_echo "Using web server ${cubevar_app_server_internal}"
  
  cube_read_stdin cubevar_app_line <<HEREDOC
    #server  ${cubevar_app_server_name} ${cubevar_app_server_internal}:80 check
    server  ${cubevar_app_server_name} ${cubevar_app_server_internal}:80 check cookie ${cubevar_app_server_name}
HEREDOC

  cubevar_app_haproxy_servers=$(cube_append_str "${cubevar_app_haproxy_servers}" "${cubevar_app_line}" "${POSIXCUBE_NEWLINE}")

  cube_read_stdin cubevar_app_line <<HEREDOC
    use-server ${cubevar_app_server_name} if { urlp(SERVERID) -i ${cubevar_app_server_name} }
HEREDOC

  cubevar_app_haproxy_servers_bypass=$(cube_append_str "${cubevar_app_haproxy_servers_bypass}" "${cubevar_app_line}" "${POSIXCUBE_NEWLINE}")
done

if cube_set_file_contents "/etc/rsyslog.d/02-haproxy.conf" "templates/rsyslog_haproxy.conf" ; then
  cube_service restart rsyslog
fi

if cube_set_file_contents "/etc/haproxy/haproxy.cfg" "templates/haproxy.cfg.template" ; then
  chmod 644 /etc/haproxy/haproxy.cfg
  cube_service restart haproxy
fi

cube_service start haproxy

if ! cube_file_exists /etc/letsencrypt/live/ ; then
  # This could fail if we're rebuilding a frontend server, and we haven't pointed the main domain IPs to the new
  # frontend yet, so we don't raise on a bad return code.
  cube_echo "Calling letsencrypt with ${cubevar_app_letsencrypt_tls_domains}"
  /usr/bin/certbot certonly --non-interactive --agree-tos --expand --email contact@myplaceonline.com --dns-digitalocean --dns-digitalocean-credentials ~/.digitalocean.ini --dns-digitalocean-propagation-seconds 120 ${cubevar_app_letsencrypt_tls_domains}
  cubevar_app_letsencrypt_result=$?
  if [ ${cubevar_app_letsencrypt_result} -ne 0 ]; then
    cube_warning_echo "Letsencrypt failure: ${cubevar_app_letsencrypt_result}"
    rm -rf /etc/letsencrypt/live/ 2>/dev/null
  fi
fi

if cube_file_exists /etc/letsencrypt/live/ ; then
  # certbot will only create a single certificate.
  #   for cubevar_app_tls_domain in ${cubevar_app_tls_domains}; do
  #     if ! cube_file_exists /etc/haproxy/ssl/${cubevar_app_tls_domain}.pem ; then
  #       cat /etc/letsencrypt/live/${cubevar_app_tls_domain}/{fullchain.pem,privkey.pem} > /etc/haproxy/ssl/${cubevar_app_tls_domain}.pem || cube_check_return
  #       cat /etc/haproxy/ssl/dh/${cubevar_app_tls_domain}.dh >> /etc/haproxy/ssl/${cubevar_app_tls_domain}.pem || cube_check_return
  #     fi
  #   done
  if ! cube_file_exists /etc/haproxy/ssl/myplaceonline.com.pem ; then
    cat /etc/letsencrypt/live/myplaceonline.com/{fullchain.pem,privkey.pem} > /etc/haproxy/ssl/myplaceonline.com.pem || cube_check_return
    cat /etc/haproxy/ssl/dh/myplaceonline.com.dh >> /etc/haproxy/ssl/myplaceonline.com.pem || cube_check_return
  fi
fi

if cube_file_exists /etc/letsencrypt/live/ ; then
  if cube_set_file_contents "/etc/haproxy/haproxy_ssl.cfg" "templates/haproxy_secure.cfg.template" ; then
    cube_service restart haproxy
  fi
fi

if cube_set_file_contents "/etc/cron.d/letsencrypt" "templates/crontab_letsencrypt.template" ; then
  chmod 600 /etc/cron.d/letsencrypt
fi

cube_service enable haproxy
cube_service start haproxy
