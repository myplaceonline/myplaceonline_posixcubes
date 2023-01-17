#!/bin/sh

cube_ensure_directory "${cubevar_app_nfs_client_mount}" 777

if ! cube_file_contains /etc/fstab "${cubevar_app_nfs_client_host}" ; then
  echo "${cubevar_app_nfs_client_host}:${cubevar_app_nfs_server_directory} ${cubevar_app_nfs_client_mount} nfs defaults,timeo=5,intr" >> /etc/fstab || cube_check_return
fi

if [ "$(df -h "${cubevar_app_nfs_client_mount}" | grep "${cubevar_app_nfs_client_host}" | wc -l)" = "0" ]; then
  mount -a || cube_check_return
  chmod a+x "${cubevar_app_nfs_client_mount}" || cube_check_return
fi

cube_ensure_directory "${cubevar_app_nfs_client_mount}" 777

true
