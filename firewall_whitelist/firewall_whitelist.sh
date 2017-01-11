#!/bin/sh

# eth0 goes into the public zone (basically just http, https, and ssh access), we set the default zone to block,
# and then whitelist every eth1 IP address into the trusted zone
#
# firewall-cmd --get-default-zone
# firewall-cmd --get-active-zones
# firewall-cmd --list-all-zones
# firewall-cmd --info-zone trusted

cube_package install firewalld

cube_service start firewalld

cube_service enable firewalld

if [ "$(firewall-cmd --get-default-zone)" != "block" ]; then
  firewall-cmd --set-default-zone=block || cube_check_return
fi

# TODO do we even need to add ZONE to ifcfg-eth0 or just use Ubuntu style --permanent in the else?
if cube_file_exists "/etc/sysconfig/network-scripts/ifcfg-eth0"; then
  if ! cube_file_contains "/etc/sysconfig/network-scripts/ifcfg-eth0" "ZONE" ; then
    echo "ZONE=public" >> "/etc/sysconfig/network-scripts/ifcfg-eth0" || cube_check_return
    firewall-cmd --zone=public --add-interface=eth0 || cube_check_return
    cube_echo "Set firewall zone of eth0 to public"
  fi
else
  if [ "$(firewall-cmd --get-zone-of-interface=eth0)" != "public" ]; then
    firewall-cmd --zone=public --add-interface=eth0 || cube_check_return
    firewall-cmd --permanent --zone=public --add-interface=eth0 || cube_check_return
    cube_echo "Set firewall zone of eth0 to public"
  fi
fi

for cubevar_app_server in ${cubevar_app_servers}; do
  cubevar_app_server_internal=$(echo "${cubevar_app_server}" | sed 's/\./-internal./')
  cubevar_app_server_internal_ip="$(dig +short ${cubevar_app_server_internal})"
  if [ "${cubevar_app_server}" != "$(cube_hostname)" ]; then
    if ! firewall-cmd -q --zone=trusted --query-source=${cubevar_app_server_internal_ip} ; then
      cube_echo "Adding ${cubevar_app_server}'s IP ${cubevar_app_server_internal_ip} to trusted whitelist"
      firewall-cmd --zone=trusted --add-source=${cubevar_app_server_internal_ip} || cube_check_return
      firewall-cmd --permanent --zone=trusted --add-source=${cubevar_app_server_internal_ip} || cube_check_return
    fi
  fi
done

# if ! cube_file_contains "/etc/sysconfig/network-scripts/ifcfg-eth1" "ZONE" ; then
#   echo "ZONE=trusted" >> "/etc/sysconfig/network-scripts/ifcfg-eth1" || cube_check_return
#   firewall-cmd --zone=trusted --add-interface=eth1 || cube_check_return
#   cube_echo "Set firewall zone of eth1 to trusted"
# fi

cube_echo "Firewall whitelist: $(firewall-cmd --zone=trusted --list-sources)"
