#!/bin/sh

cube_include install_opensmtpd

if cube_set_file_contents "/usr/local/etc/smtpd.conf" "templates/smtpd.conf.template"; then
  cube_service restart opensmtpd
fi
