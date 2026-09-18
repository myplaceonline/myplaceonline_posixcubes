#!/bin/sh

# See matching stop in server_core
if cube_service_exists crond ; then
  cube_service start crond
elif cube_service_exists cron ; then
  cube_service start cron
fi
