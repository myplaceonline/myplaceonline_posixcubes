#!/bin/sh

cubevar_app_hostname=$(echo "$(cube_hostname)" | sed 's/\./-internal./') || cube_check_return
cubevar_app_hostname="http://${cubevar_app_hostname}/admin/reinitialize"

cube_echo Executing ${cubevar_app_hostname}

curl "${cubevar_app_hostname}" || cube_check_return
