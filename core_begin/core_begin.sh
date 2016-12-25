#!/bin/sh

cube_read_heredoc <<'HEREDOC'; cubevar_app_motd="${cube_read_heredoc_result}"

                        _                            _ _            
                       | |                          | (_)           
  _ __ ___  _   _ _ __ | | __ _  ___ ___  ___  _ __ | |_ _ __   ___ 
 | '_ ` _ \| | | | '_ \| |/ _` |/ __/ _ \/ _ \| '_ \| | | '_ \ / _ \
 | | | | | | |_| | |_) | | (_| | (_|  __/ (_) | | | | | | | | |  __/
 |_| |_| |_|\__, | .__/|_|\__,_|\___\___|\___/|_| |_|_|_|_| |_|\___|
             __/ | |                                                
            |___/|_|                                                



HEREDOC

echo "${cubevar_app_motd}"

# Description:
#   Set system timezone to $1
# Example call:
#   cube_set_timezone UTC
# Arguments:
#   Required:
#     $1: Relative time zone path under /usr/share/zoneinfo/
cube_core_set_timezone() {
  cube_check_numargs 1 "${@}"
  ! cube_check_file_exists /usr/share/zoneinfo/${1} && cube_throw "Time zone ${1} doesn't exist"
  if [ "$(cube_readlink /etc/localtime)" != "/usr/share/zoneinfo/${1}" ]; then
    ln -sf /usr/share/zoneinfo/${1} /etc/localtime || cube_check_return
    cube_echo "Updated system time zone to /usr/share/zoneinfo/${1}"
    export TZ=$1
  else
    [ "${TZ}" = "" ] && export TZ=$1
  fi
  return 0
}

cube_core_set_timezone UTC

df -h | grep -v tmpfs
echo ""
free -m
echo ""
grep -e processor -e MHz /proc/cpuinfo
echo ""
grep -e MemTotal -e MemFree -e Buffers -e ^Cached /proc/meminfo
echo ""

cube_package install firewalld

cube_service start firewalld

cube_service enable firewalld

if ! cube_file_contains "/etc/sysconfig/network-scripts/ifcfg-eth0" "ZONE" ; then
  echo "ZONE=public" >> "/etc/sysconfig/network-scripts/ifcfg-eth0" || cube_check_return
  firewall-cmd --zone=public --add-interface=eth0 || cube_check_return
  cube_echo "Set firewall zone of eth0 to public"
fi

if ! cube_file_contains "/etc/sysconfig/network-scripts/ifcfg-eth1" "ZONE" ; then
  echo "ZONE=trusted" >> "/etc/sysconfig/network-scripts/ifcfg-eth1" || cube_check_return
  firewall-cmd --zone=trusted --add-interface=eth1 || cube_check_return
  cube_echo "Set firewall zone of eth1 to trusted"
fi

# Machines may be memory constrained, so disable crons for the duration
# of the chef-client run. Re-enable in the core_end cube
cube_check_dir_exists "/etc/cron.d" && cube_service stop crond

# Ensure permissive selinux
if cube_check_dir_exists "/etc/selinux/" && cube_set_file_contents "/etc/selinux/config" "templates/selinux_config" ; then
  setenforce Permissive || cube_check_return
fi

cube_set_file_contents_string ~/.passwd ${cubevar_app_passwords_root}

# We set a user password in the case we need to do a manual login from the web console
passwd --stdin root < ~/.passwd
rm -f ~/.passwd

if cube_set_file_contents "/etc/commonprofile.sh" "templates/commonprofile.sh" ; then
  chmod 755 "/etc/commonprofile.sh" || cube_check_return
  cube_set_file_contents "/etc/profile" "templates/profile"
fi

cube_set_file_contents_string "/etc/motd" "${cubevar_app_motd}"

if cube_set_file_contents "/etc/sysctl.conf" "templates/sysctl.conf" ; then
  sysctl -p || cube_check_return
fi

if cube_set_file_contents "/etc/systemd/system/myplaceonline-networkup.service" "templates/myplaceonline-networkup.service.template" ; then
  cube_service daemon-reload
  cube_service enable myplaceonline-networkup
fi

cube_service restart myplaceonline-networkup

if cube_set_file_contents "/etc/systemd/journald.conf" "templates/journald.conf" ; then
  cube_service restart systemd-journald
fi

cube_package install python python-dnf multitail htop lsof wget nfs-utils at

cube_service enable atd
cube_service start atd

cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo install kernel-debuginfo-common-x86_64 kernel-debuginfo glibc-debuginfo-common glibc-debuginfo systemtap perf

if cube_set_file_contents "/var/chef/cache/cookbooks/dnf/libraries/dnf-query.py" "templates/dnf-query.py" ; then
  chmod 755 "/var/chef/cache/cookbooks/dnf/libraries/dnf-query.py" || cube_check_return
fi

# https://www.elastic.co/guide/en/logstash/current/installing-logstash.html
cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"
[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/7Server/\$basearch/stable
enabled = 1
gpgcheck = 0
gpgkey = https://repos.influxdata.com/influxdb.key

[logstash-5.x]
name=Elastic repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
HEREDOC

cube_set_file_contents_string "/etc/yum.repos.d/influxdb.repo" "${cubevar_app_str}"

cube_package install multitail strace htop mtr traceroute patch atop sysstat iotop gdb bind-utils ntp python sendmail make mailx postfix tcpdump cyrus-sasl-plain rsyslog gnupg kexec-tools lzo lzo-devel lzo-minilzo bison bison-devel ncurses ncurses-devel telegraf telnet iftop git nmap-ncat logstash java-1.8.0-openjdk

cube_service enable atop
cube_service start atop

if cube_set_file_contents "/etc/rsyslog.conf" "templates/rsyslog.conf" ; then
  # Some servers have a different syslog config, so don't update syslog immediately
  cubevar_api_post_restart=$(cube_append_str "${cubevar_api_post_restart}" "rsyslog")
fi

cube_set_file_contents "/etc/kdump.conf" "templates/kdump.conf"

# don't auto-start because we may not have crashkernel yet
cube_service enable kdump

# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html-single/Kernel_Crash_Dump_Guide/index.html#sect-kdump-memory-requirements
# 160 MB + 2 bits for every 4 KB of RAM. For a system with 1 TB of memory, 224 MB is the minimum (160 + 64 MB). 
cubevar_app_crashkernel_mem=$((161+($(cube_total_memory)/268435456)))
if cube_set_file_contents "/etc/default/grub" "templates/grub.template" ; then
  /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
fi

cube_ensure_directory ~/.ssh/ 700
cube_ensure_file ~/.ssh/authorized_keys 700

cube_package update
cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo update

cube_service enable ntpd
cube_service start ntpd

# To test sending mail from the box:
#   echo "Message body" | mail -s "Subject" -r from@example.com to@example.com
cube_set_file_contents "/etc/postfix/main.cf" "templates/main.cf.template"

cube_service enable postfix
cube_service start postfix

cube_set_file_contents "/etc/security/limits.conf" "templates/limits.conf"

cube_set_file_contents ~/.toprc "templates/toprc"

if ! cube_check_file_exists /usr/local/src/crash/crash ; then
  cube_pushd /usr/local/src/
  rm -rf crash* || cube_check_return
  git clone https://github.com/crash-utility/crash/ || cube_check_return
  cd crash || cube_check_return
  echo '-DLZO' > CFLAGS.extra || cube_check_return
  echo '-llzo2' > LDFLAGS.extra || cube_check_return
  make || cube_check_return
  cube_popd
fi

if ! cube_has_role "syslog_server" ; then
  if cube_set_file_contents "/etc/rsyslog.d/01-client.conf" "templates/rsyslog_client.conf.template" ; then
    cube_service restart rsyslog
  fi
fi
