#!/bin/sh
firewall-cmd --permanent --zone=trusted --remove-interface=eth1 || cube_check_return
firewall-cmd --set-default-zone=block || cube_check_return 
sed -i 's/ZONE=trusted//g' /etc/sysconfig/network-scripts/ifcfg-eth1 || cube_check_return
