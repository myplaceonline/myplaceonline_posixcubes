#!/bin/sh

cube_package install nfs-utils

cube_ensure_directory "${cubevar_app_nfs_server_directory}" 700

cube_set_file_contents "/etc/sysconfig/rpcbind" "templates/rpcbind"

cube_service enable rpcbind
cube_service start rpcbind

if cube_set_file_contents "/etc/exports" "templates/exports.template" ; then
  cube_service restart nfs-server
fi

cube_service enable nfs-server
cube_service start nfs-server
