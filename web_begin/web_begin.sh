#!/bin/sh

# Turn maintenance on at haproxy
app_haproxy_result="$(curl -s -S -u "admin:${cubevar_app_passwords_haproxy_stats}" -d "s=$(cube_hostname "true")" -d "action=drain" -d "b=#4" -w "%{redirect_url}" "${cubevar_app_passwords_haproxy_url}")" || cube_check_return

app_haproxy_result="$(echo "${app_haproxy_result}" | sed 's/.*;st=//g')"

cube_echo "Draining $(cube_hostname "true") result: ${app_haproxy_result}. Waiting ${cubevar_app_passwords_haproxy_drainseconds} seconds..."

sleep ${cubevar_app_passwords_haproxy_drainseconds}

app_haproxy_result="$(curl -s -S -u "admin:${cubevar_app_passwords_haproxy_stats}" -d "s=$(cube_hostname "true")" -d "action=maint" -d "b=#4" -w "%{redirect_url}" "${cubevar_app_passwords_haproxy_url}")" || cube_check_return

app_haproxy_result="$(echo "${app_haproxy_result}" | sed 's/.*;st=//g')"

cube_echo "Setting maintenance mode on $(cube_hostname "true") result: ${app_haproxy_result}. Waiting ${cubevar_app_passwords_haproxy_maintseconds} seconds..."

sleep ${cubevar_app_passwords_haproxy_maintseconds}

# Ruby uses a lot of memory, so first stop weighty processes. Wrap in a sub-shell to eat any exceptions (e.g. if
# first setting up the box and the service doesn't exist)
(cube_service stop nginx) 2>/dev/null

(cube_service stop myplaceonline-delayedjobs) 2>/dev/null

true
