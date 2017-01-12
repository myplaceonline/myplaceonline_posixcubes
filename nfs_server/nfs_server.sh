#!/bin/sh

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package install nfs-utils
  cubevar_nfs_server_service="nfs-server"
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  # https://help.ubuntu.com/lts/serverguide/network-file-system.html
  cube_package install nfs-kernel-server
  cubevar_nfs_server_service="nfs-kernel-server"
else
  cube_throw Not implemented
fi

cube_ensure_directory "${cubevar_app_nfs_server_directory}" 700

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_set_file_contents "/etc/sysconfig/rpcbind" "templates/rpcbind"

  cube_service enable rpcbind
  cube_service start rpcbind
fi

if cube_set_file_contents "/etc/exports" "templates/exports.template" ; then
  cube_service restart ${cubevar_nfs_server_service}
fi

cube_service enable ${cubevar_nfs_server_service}
cube_service start ${cubevar_nfs_server_service}
