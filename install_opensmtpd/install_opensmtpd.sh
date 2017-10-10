#!/bin/sh

cube_package install automake git libtool libevent-devel libasr-devel openssl openssl-devel

if ! cube_dir_exists "/usr/local/src/opensmtpd-201702130941p1/" ; then
  (
    cd /usr/local/src/ || cube_check_return
    wget http://www.opensmtpd.org/archives/opensmtpd-portable-latest.tar.gz || cube_check_return
    tar xzvf opensmtpd-portable-latest.tar.gz || cube_check_return
    cd opensmtpd-201702130941p1 || cube_check_return
    ./configure --with-path-CAfile=/etc/pki/tls/cert.pem || cube_check_return
    make || cube_check_return
    make install || cube_check_return
    ln -s /etc/pki/tls/cert.pem /etc/ssl/cert.pem
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

if ! cube_file_exists /etc/mail/secrets ; then
  touch /etc/mail/secrets || cube_check_return
  chmod 640 /etc/mail/secrets || cube_check_return
  chown root:_smtpd /etc/mail/secrets || cube_check_return
  cube_set_file_contents_string "/etc/mail/secrets" "label myplaceonline:${cubevar_app_passwords_smtp}"
fi

if cube_set_file_contents "/usr/lib/systemd/system/opensmtpd.service" "templates/opensmtpd.service.template" ; then
  cube_service daemon-reload
  cube_service enable opensmtpd
  cube_service restart opensmtpd
fi
