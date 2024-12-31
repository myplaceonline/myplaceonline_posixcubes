#!/bin/sh

# smtpctl show queue
# Fix error (e.g. systemctl start dkimproxy_out)
# smtpctl schedule all

# Create user
# Generate password (no prompt; type password twice):
#   ssh root@${HOST} doveadm pw -s SHA512-CRYPT
#   or
#   https://myplaceonline.com/info/diagnostics/dovecot_password
# Take everything from $6$ to the end and add a line to cubevar_app_email_passwords following the passwd format
# If it's a new domain, add to cubevar_app_email_domains and cubevar_app_email_dkim_domains
# Add a vmail line to cubevar_app_email_users for the user
# Build email_server to update the files: posixcube.sh -h root@${SERVER} -c email_server

# User: user@domain
# Type: IMAP
# Incoming Port: 993
# Incoming Encryption: SSL/TLS
# Incoming Authentication: Normal Password
# Outgoing Port: 587
# Outgoing Encryption: STARTTLS
# Outgoing Authentication: Normal Password

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

# When deleting emails from an IMAP client, they are only marked deleted. To expunge:
# doveadm expunge -A mailbox Trash all
# doveadm expunge -u $user@$host mailbox Trash all

cube_package install certbot python3-certbot-dns-digitalocean automake git libtool libevent-devel libasr-devel \
                     dovecot dovecot-pigeonhole perl-Crypt-OpenSSL-RSA perl-Digest-SHA perl-MailTools perl-Net-DNS \
                     perl-Net-Server perl-Mail-DKIM spamassassin spampd

cube_ensure_directory "${cubevar_app_mail_dir}" 777

if ! cube_file_exists /etc/letsencrypt/live/ ; then
  cube_echo "Calling letsencrypt"
  /usr/bin/certbot certonly --non-interactive --agree-tos --expand --email contact@myplaceonline.com --dns-digitalocean --dns-digitalocean-credentials ~/.digitalocean.ini --dns-digitalocean-propagation-seconds 120 -d ${cubevar_app_email_host}
  cubevar_app_letsencrypt_result=$?
  if [ ${cubevar_app_letsencrypt_result} -ne 0 ]; then
    cube_warning_echo "Letsencrypt failure: ${cubevar_app_letsencrypt_result}"
    rm -rf /etc/letsencrypt/live/ 2>/dev/null
  else
    chmod 600 /etc/letsencrypt/archive/$(hostname)/*.pem || cube_check_return
  fi
fi

cube_set_file_contents "/etc/mail/spamassassin/local.cf" "templates/local.cf.template"
cube_set_file_contents "/etc/sysconfig/spampd" "templates/spampd.template"

cube_service enable spampd
cube_service restart spampd

# https://www.opensmtpd.org/faq/example1.html
if ! cube_user_exists vmail; then
  useradd -m -c "Virtual Mail" -d ${cubevar_app_mail_dir} -s /sbin/nologin vmail || cube_check_return
  usermod -g mail vmail || cube_check_return
fi

if ! cube_file_exists /etc/mail/aliases ; then
  cube_set_file_contents_string "/etc/mail/aliases" "${cubevar_app_email_aliases}"
  cube_set_file_contents_string "/etc/mail/domains" "${cubevar_app_email_domains}"
  cube_set_file_contents_string "/etc/mail/passwd" "${cubevar_app_email_passwords}"
  cube_set_file_contents_string "/etc/mail/users" "${cubevar_app_email_users}"
fi

if ! cube_file_exists /etc/mail/secrets ; then
  touch /etc/mail/secrets || cube_check_return
  chmod 640 /etc/mail/secrets || cube_check_return
  chown root:smtpd /etc/mail/secrets || cube_check_return
  cube_set_file_contents_string "/etc/mail/secrets" "label ${cubevar_app_passwords_smtp_user}:${cubevar_app_passwords_smtp_password}"
fi

# http://dkimproxy.sourceforge.net/download.html
if ! cube_dir_exists "/usr/local/src/dkimproxy-1.4.1" ; then
  (
    cd /usr/local/src/ || cube_check_return
    wget https://downloads.sourceforge.net/dkimproxy/dkimproxy-1.4.1.tar.gz || cube_check_return
    tar xzvf dkimproxy-1.4.1.tar.gz || cube_check_return
    rm -f dkimproxy-1.4.1.tar.gz || cube_check_return
    cd dkimproxy* || cube_check_return
    ./configure --prefix=/usr/local/dkimproxy || cube_check_return
    make install || cube_check_return
  ) || cube_check_return
fi

if ! cube_user_exists "dkim" ; then
  cube_create_user "dkim"
fi

cube_set_file_contents "/usr/local/dkimproxy/etc/dkimproxy_in.conf" "templates/dkimproxy_in.conf.template"
cube_set_file_contents "/usr/local/dkimproxy/etc/dkimproxy_out.conf" "templates/dkimproxy_out.conf.template"

if cube_set_file_contents "/etc/systemd/system/dkimproxy_in.service" "templates/dkimproxy_in.service.template" ; then
  cube_service daemon-reload
fi

if cube_set_file_contents "/etc/systemd/system/dkimproxy_out.service" "templates/dkimproxy_out.service.template" ; then
  cube_service daemon-reload
fi

if cube_set_file_contents "/usr/local/dkimproxy/bin/dkimproxy.sh" "templates/dkimproxy.sh"; then
  chmod a+x /usr/local/dkimproxy/bin/dkimproxy.sh || cube_check_return
fi

# http://dkimproxy.sourceforge.net/usage.html

if cube_set_file_contents_string "/usr/local/dkimproxy/etc/private.key" "${cubevar_app_dkim_key_private}"; then
  chown dkim:dkim /usr/local/dkimproxy/etc/private.key || cube_check_return
  chmod 600 /usr/local/dkimproxy/etc/private.key || cube_check_return
fi

cube_set_file_contents_string "/usr/local/dkimproxy/etc/public.key" "${cubevar_app_dkim_key_public}"
cube_set_file_contents "/usr/local/dkimproxy/etc/dkimproxy_in.conf" "templates/dkimproxy_in.conf.template"
cube_set_file_contents "/usr/local/dkimproxy/etc/dkimproxy_out.conf" "templates/dkimproxy_out.conf.template"

cube_service enable dkimproxy_in
cube_service restart dkimproxy_in

cube_service enable dkimproxy_out
cube_service restart dkimproxy_out

cube_set_file_contents "/etc/dovecot/conf.d/10-ssl.conf" "templates/10-ssl.conf.template"
cube_set_file_contents "/etc/dovecot/conf.d/auth-system.conf.ext" "templates/auth-system.conf.ext.template"
cube_set_file_contents "/etc/dovecot/conf.d/10-mail.conf" "templates/10-mail.conf.template"
cube_set_file_contents "/etc/dovecot/conf.d/15-mailboxes.conf" "templates/15-mailboxes.conf.template"
cube_set_file_contents "/etc/dovecot/conf.d/10-master.conf" "templates/10-master.conf.template"
cube_set_file_contents "/etc/dovecot/conf.d/90-sieve.conf" "templates/90-sieve.conf.template"
cube_set_file_contents "/etc/dovecot/conf.d/20-lmtp.conf" "templates/20-lmtp.conf.template"
cube_set_file_contents "/etc/dovecot/conf.d/10-logging.conf" "templates/10-logging.conf.template"

# Read global sieves
chmod o+rx /var/lib/dovecot || cube_check_return
if cube_set_file_contents "/var/lib/dovecot/10-global.sieve" "templates/10-global.sieve.template"; then
  sievec /var/lib/dovecot/ || cube_check_return
  cube_echo "Recompiled sieves in /var/lib/dovecot/"
fi

cube_service enable dovecot
cube_service restart dovecot

cube_package install opensmtpd mariadb-devel

if ! cube_dir_exists "/usr/local/src/OpenSMTPD-extras" ; then
  (
    cd /usr/local/src/ || cube_check_return
    git clone https://github.com/OpenSMTPD/OpenSMTPD-extras.git || cube_check_return
    cd OpenSMTPD-extras || cube_check_return
    sh bootstrap || cube_check_return
    ./configure --libexecdir=/usr/libexec --with-table-passwd --with-filter-stub --with-queue-ram || cube_check_return
    make || cube_check_return
    make install || cube_check_return
  ) || cube_check_return
fi

cube_set_file_contents "/etc/opensmtpd/smtpd.conf" "templates/smtpd.conf.template"
cube_set_file_contents_string "/etc/mail/aliases" "${cubevar_app_email_aliases}"
cube_set_file_contents_string "/etc/mail/domains" "${cubevar_app_email_domains}"
cube_set_file_contents_string "/etc/mail/passwd" "${cubevar_app_email_passwords}"
cube_set_file_contents_string "/etc/mail/users" "${cubevar_app_email_users}"

if cube_set_file_contents "/usr/lib/systemd/system/opensmtpd.service" "templates/opensmtpd.service.template" ; then
  cube_service daemon-reload
fi

cube_service enable opensmtpd
cube_service restart opensmtpd

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

# if cube_user_ensure_private_key "${cubevar_app_backup_user_ssh_key_private}" "backup_user"; then
#   cube_user_authorize_known_host "${cubevar_app_backup_host}"
# fi
#
# if cube_set_file_contents_string "/etc/cron.d/backupmail" "0 0 * * * date >> /var/log/backupmail.log 2>&1 && rsync -ar -e 'ssh -i /root/.ssh/backup_user' /var/vmail backup_user@${cubevar_app_backup_host}:/home/backup_user/ >> /var/log/backupmail.log 2>&1" ; then
#   chmod 600 /etc/cron.d/backupmail || cube_check_return
# fi
