#!/bin/sh

cubevar_app_hostname=$(cube_hostname)

# To test sending mail from the box:
#   echo "Message body" | mail -s "Subject" -r from@example.com to@example.com
if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_set_file_contents "/etc/postfix/main.cf" "templates/main.cf.fedora.template"
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  cube_set_file_contents_string "/etc/mailname" "myplaceonline.com"
  cube_set_file_contents "/etc/postfix/main.cf" "templates/main.cf.debian.template"
else
  cube_throw Not implemented
fi

cube_service enable postfix
cube_service start postfix
