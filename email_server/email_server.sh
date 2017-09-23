#!/bin/sh

# IMAP:
  # openssl s_client -connect ${HOST}:993 -crlf
  # tag login ${USER} "${PASSWORD}"
  # tag LIST "" "*"
  # tag SELECT INBOX
  # tag STATUS INBOX (MESSAGES)
  # tag FETCH 1 (BODY[HEADER])
  # tag LOGOUT

# SMTP (note, the "RCPT TO" command must be lowercase; otherwise, openssl thinks it's a RENEGOTIATE command)
  # openssl s_client -host ${HOST} -port 587 -starttls smtp -crlf
  # EHLO test
  # MAIL FROM:<test@test.com>
  # rCPT TO:<test@test.com>
  # DATA
  #   From: <test@test.com>
  #   Subject: Hello World
  #   
  #   Test
  #   .
  # QUIT

# Generate password (no prompt; type password twice):
# ssh root@${HOST} doveadm pw -s SHA512-CRYPT

# Check if IP address is blacklisted
# http://mxtoolbox.com/blacklists.aspx
# http://whatismyipaddress.com/blacklist-check
# http://multirbl.valli.org/
# https://www.spamhaus.org/lookup/

# Check sender score
# https://senderscore.org/

# Reverse IP lookup
# host ${IP_ADDRESS}

# Test emails
# https://www.mail-tester.com/
# http://www.checktls.com/testreceiver.html

# Configuration
# http://www.dkim.org
# http://www.openspf.org
# DNSSEC
# DMARC

# Whitelisting
# https://postmaster.live.com/snds/JMRP.aspx

# Hints
# Don't append X-Originating-IP (https://major.io/2013/04/14/remove-sensitive-information-from-email-headers-with-postfix/)

# For certbot
if [ "$(firewall-cmd --zone=public --list-ports | grep -c 80)" = "0" ]; then
  firewall-cmd --zone=public --add-port=80/tcp
  firewall-cmd --zone=public --permanent --add-port=80/tcp
  cube_echo "Opened firewall port for port 80"
fi

# For certbot
if [ "$(firewall-cmd --zone=public --list-ports | grep -c 443)" = "0" ]; then
  firewall-cmd --zone=public --add-port=443/tcp
  firewall-cmd --zone=public --permanent --add-port=443/tcp
  cube_echo "Opened firewall port for port 443"
fi

if ! cube_file_exists /etc/letsencrypt/live/ ; then
  # This could fail if we're rebuilding a frontend server, and we haven't pointed the main domain IPs to the new
  # box yet, so we don't raise on a bad return code.
  cube_echo "Calling letsencrypt"
  /usr/bin/certbot --non-interactive --agree-tos --renew-by-default --email contact@myplaceonline.com --standalone certonly -d ${cubevar_app_email_host}
  cubevar_app_letsencrypt_result=$?
  if [ ${cubevar_app_letsencrypt_result} -ne 0 ]; then
    cube_warning_echo "Letsencrypt failure: ${cubevar_app_letsencrypt_result}"
    rm -rf /etc/letsencrypt/live/ 2>/dev/null
  fi
fi

cube_package install certbot automake git libtool libevent-devel libasr-devel dovecot

# https://www.opensmtpd.org/faq/example1.html
if ! cube_user_exists vmail; then
  useradd -m -c "Virtual Mail" -d /var/vmail -s /sbin/nologin vmail || cube_check_return
  usermod -g mail vmail || cube_check_return
fi

if ! cube_file_exists /etc/mail/aliases ; then
  cube_set_file_contents_string "/etc/mail/aliases" "${cubevar_app_email_aliases}"
  cube_set_file_contents_string "/etc/mail/domains" "${cubevar_app_email_domains}"
  cube_set_file_contents_string "/etc/mail/passwd" "${cubevar_app_email_passwords}"
  cube_set_file_contents_string "/etc/mail/users" "${cubevar_app_email_users}"
fi

if cube_set_file_contents "/etc/dovecot/conf.d/10-ssl.conf" "templates/10-ssl.conf.template"; then
  cube_service restart dovecot
fi

if cube_set_file_contents "/etc/dovecot/conf.d/auth-system.conf.ext" "templates/auth-system.conf.ext.template"; then
  cube_service restart dovecot
fi

if cube_set_file_contents "/etc/dovecot/conf.d/10-mail.conf" "templates/10-mail.conf.template"; then
  cube_service restart dovecot
fi

if cube_set_file_contents "/etc/dovecot/conf.d/10-master.conf" "templates/10-master.conf.template"; then
  cube_service restart dovecot
fi

cube_service enable dovecot
cube_service start dovecot

! cube_file_exists /etc/mail/passwd && touch /etc/mail/passwd

if ! cube_dir_exists "/usr/local/src/opensmtpd-201702130941p1/" ; then
  (
    cd /usr/local/src/ || cube_check_return
    wget http://www.opensmtpd.org/archives/opensmtpd-portable-latest.tar.gz || cube_check_return
    tar xzvf opensmtpd-portable-latest.tar.gz || cube_check_return
    cd opensmtpd* || cube_check_return
    ./configure || cube_check_return
    make || cube_check_return
    sudo make install || cube_check_return
    useradd -m -c "SMTP Daemon" -d /var/empty -s /sbin/nologin _smtpd || cube_check_return
    useradd -m -c "SMTPD Queue" -d /var/empty -s /sbin/nologin _smtpq || cube_check_return
    cd /usr/local/src/ || cube_check_return
    git clone https://github.com/OpenSMTPD/OpenSMTPD-extras.git
    cd OpenSMTPD-extras
    sh bootstrap
    ./configure --libexecdir=/usr/local/libexec/ --with-table-passwd
    make
    make install
  ) || cube_check_return
fi

if cube_set_file_contents "/usr/local/etc/smtpd.conf" "templates/smtpd.conf.template"; then
  cube_service restart opensmtpd
fi

if cube_set_file_contents "/usr/lib/systemd/system/opensmtpd.service" "templates/opensmtpd.service.template" ; then
  cube_service daemon-reload
  cube_service enable opensmtpd
  cube_service restart opensmtpd
fi

if cube_set_file_contents_string "/etc/mail/aliases" "${cubevar_app_email_aliases}" ; then
  cube_service restart opensmtpd
fi

if cube_set_file_contents_string "/etc/mail/domains" "${cubevar_app_email_domains}" ; then
  cube_service restart opensmtpd
fi

if cube_set_file_contents_string "/etc/mail/passwd" "${cubevar_app_email_passwords}" ; then
  cube_service restart opensmtpd
fi

if cube_set_file_contents_string "/etc/mail/users" "${cubevar_app_email_users}" ; then
  cube_service restart opensmtpd
fi

if cube_set_file_contents "/etc/cron.d/letsencrypt" "templates/crontab_letsencrypt.template" ; then
  chmod 600 /etc/cron.d/letsencrypt
fi

# SMTP
if [ "$(firewall-cmd --zone=public --list-ports | grep -c 25)" = "0" ]; then
  firewall-cmd --zone=public --add-port=25/tcp
  firewall-cmd --zone=public --permanent --add-port=25/tcp
  cube_echo "Opened firewall port for port 25"
fi

if [ "$(firewall-cmd --zone=public --list-ports | grep -c 465)" = "0" ]; then
  firewall-cmd --zone=public --add-port=465/tcp
  firewall-cmd --zone=public --permanent --add-port=465/tcp
  cube_echo "Opened firewall port for port 465"
fi

if [ "$(firewall-cmd --zone=public --list-ports | grep -c 587)" = "0" ]; then
  firewall-cmd --zone=public --add-port=587/tcp
  firewall-cmd --zone=public --permanent --add-port=587/tcp
  cube_echo "Opened firewall port for port 587"
fi

# IMAP
if [ "$(firewall-cmd --zone=public --list-ports | grep -c 993)" = "0" ]; then
  firewall-cmd --zone=public --add-port=993/tcp
  firewall-cmd --zone=public --permanent --add-port=993/tcp
  cube_echo "Opened firewall port for port 993"
fi
