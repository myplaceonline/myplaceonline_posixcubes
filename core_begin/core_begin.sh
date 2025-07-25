#!/bin/sh

cube_read_stdin cubevar_app_motd <<'HEREDOC'

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

if ! cube_user_exists "${cubevar_app_test_user}" ; then
  cube_create_user "${cubevar_app_test_user}" "" "${cubevar_app_test_user_password}"
  if cube_group_exists "sudo" ; then
    cube_add_group_user "sudo" "${cubevar_app_test_user}"
  elif cube_group_exists "wheel" ; then
    cube_add_group_user "wheel" "${cubevar_app_test_user}"
  fi
fi

if ! cube_file_exists "/etc/sudoers.d/90-cloud-init-users" ; then
  cube_read_stdin cubevar_app_sudoers_nopasswd <<'HEREDOC'
# User rules for root
root ALL=(ALL) NOPASSWD:ALL
%sudo ALL=(ALL) NOPASSWD:ALL
HEREDOC
  cube_set_file_contents_string "/etc/sudoers.d/90-cloud-init-users" "${cubevar_app_sudoers_nopasswd}"
fi

# Description:
#   Set system timezone to $1
# Example call:
#   cube_set_timezone UTC
# Arguments:
#   Required:
#     $1: Relative time zone path under /usr/share/zoneinfo/
cube_core_set_timezone() {
  cube_check_numargs 1 "${@}"
  ! cube_file_exists /usr/share/zoneinfo/${1} && cube_throw "Time zone ${1} doesn't exist"
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

# Machines may be memory constrained. Even things like the package manager
# checking for updates may throw them over the edge, so stop various services
# for the duration of the cubeset (they should be started later as part of the
# cubes).
if cube_service_exists crond ; then
  cube_service stop crond
elif cube_service_exists cron ; then
  cube_service stop cron
fi
if cube_service_exists grafana-server ; then
  cube_service stop grafana-server
fi
if cube_service_exists elasticsearch ; then
  cube_service stop elasticsearch
fi
#if cube_service_exists influx ; then
#  cube_service stop influxd
#fi

cubevar_app_fullhostname="$(cube_hostname true).${cubevar_app_server_name}"
cubevar_app_shorthostname="$(cube_hostname true)"

cube_read_stdin cubevar_app_str <<'HEREDOC'
${cubevar_app_fullhostname}
HEREDOC

if cube_set_file_contents_string "/etc/hostname" "${cubevar_app_str}"; then
  hostname ${cubevar_app_fullhostname} || cube_check_return
fi

cube_include firewall_whitelist false

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN} ; then
  cube_package update
  cube_package install selinux-utils
fi

# Ensure permissive selinux
if cube_dir_exists "/etc/selinux/" && cube_set_file_contents "/etc/selinux/config" "templates/selinux_config" && [ "$(getenforce)" != "Disabled" ] ; then
  setenforce Permissive || cube_check_return
fi

# We set a user password in the case we need to do a manual login from the web console
echo "root:${cubevar_app_passwords_root}" | chpasswd || cube_check_return

#cube_set_file_contents_string ~/.passwd ${cubevar_app_passwords_root}
#passwd --stdin root < ~/.passwd || cube_check_return
#rm -f ~/.passwd

echo "dns_digitalocean_token=${cubevar_app_digital_ocean_api_token}" > ~/.digitalocean.ini || cube_check_return
chmod 600 ~/.digitalocean.ini || cube_check_return

echo "dns_cloudflare_api_token=${cubevar_app_cloudflare_api_token}" > ~/.cloudflare.ini || cube_check_return
chmod 600 ~/.cloudflare.ini || cube_check_return

cube_set_file_contents "/etc/profile" "templates/profile"

if cube_set_file_contents "/etc/commonprofile.sh" "templates/commonprofile.sh" ; then
  chmod 755 "/etc/commonprofile.sh" || cube_check_return
fi

cube_set_file_contents_string "/etc/motd" "${cubevar_app_motd}"

if cube_set_file_contents "/etc/sysctl.conf" "templates/sysctl.conf" ; then
  sysctl -p || cube_check_return
fi

if cube_set_file_contents "/etc/systemd/journald.conf" "templates/journald.conf" ; then
  cube_service restart systemd-journald
fi

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package install python multitail htop lsof wget nfs-utils at
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  cube_package install python multitail htop lsof wget nfs-common at apt-transport-https
else
  cube_throw Not implemented
fi

cube_service enable atd
cube_service start atd

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then

  #cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo install kernel-debuginfo-common-x86_64 kernel-debuginfo glibc-common-debuginfo glibc-debuginfo systemtap perf
  #cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo install systemtap perf

  # https://fedoraproject.org/wiki/Yum_to_DNF_Cheatsheet
  if [ $(cube_operating_system_version_major) -lt 26 ]; then
    cubevar_redundant_packages="$(dnf repoquery --installonly --latest-limit -1 -q)"
  else
    cubevar_redundant_packages="$(dnf repoquery --installonly --latest-limit=-1 -q)"
  fi
  if [ "${cubevar_redundant_packages}" != "" ]; then
    cube_package remove ${cubevar_redundant_packages}
    #true
  fi
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  # https://wiki.ubuntu.com/DebuggingProgramCrash#Debug_Symbol_Packages
  if ! cube_file_exists /etc/apt/sources.list.d/ddebs.list ; then
    if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_UBUNTU}; then
      echo "deb http://ddebs.ubuntu.com $(lsb_release -cs) main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
      # The following is in one of the Ubuntu guides but returns:
      # W: The repository 'http://ddebs.ubuntu.com xenial-security Release' does not have a Release file.
      #echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-security main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
      echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-updates main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
      echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-proposed main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
      apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5FDFF622 || cube_check_return
      apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ECDCAD72428D7C01 || cube_check_return
      cube_package update || cube_check_return

      # https://wiki.ubuntu.com/Kernel/Systemtap
      cube_package install linux-image-$(uname -r)-dbgsym linux-headers-$(uname -r) systemtap linux-tools-generic linux-crashdump
      
    # TODO couldn't figure out where to get linux-image*dbgsym on Debian
    #elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
    fi
  fi
else
  cube_throw Not implemented
fi

# https://www.elastic.co/guide/en/logstash/current/installing-logstash.html
# https://docs.influxdata.com/telegraf/v1.1/introduction/installation/
if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
#   cube_read_stdin cubevar_app_str <<'HEREDOC'
# [influxdb]
# name = InfluxDB Repository - RHEL $releasever
# baseurl = https://repos.influxdata.com/rhel/7Server/$basearch/stable
# enabled = 1
# gpgcheck = 0
# gpgkey = https://repos.influxdata.com/influxdb.key
# HEREDOC
# 
#   cube_set_file_contents_string "/etc/yum.repos.d/influxdb.repo" "${cubevar_app_str}"
# 
#   cube_read_stdin cubevar_app_str <<'HEREDOC'
# [logstash-5.x]
# name=Elastic repository for 5.x packages
# baseurl=https://artifacts.elastic.co/packages/5.x/yum
# gpgcheck=0
# gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
# enabled=1
# autorefresh=1
# type=rpm-md
# HEREDOC
# 
#   cube_set_file_contents_string "/etc/yum.repos.d/logstash.repo" "${cubevar_app_str}"
  
  if ! cube_file_exists /etc/yum.repos.d/rpmfusion-free.repo ; then
    cube_package install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
  fi
  
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  if ! cube_file_exists /etc/apt/sources.list.d/elastic-5.x.list ; then
    cube_app_tmp="$(wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch || cube_check_return)" || cube_check_return
    printf '%s' "${cube_app_tmp}" | apt-key add - || cube_check_return
    echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-5.x.list || cube_check_return
    cube_package update
  fi
  
#   if ! cube_file_exists /etc/apt/sources.list.d/influxdb.list ; then
#     cube_app_tmp="$(curl -sL https://repos.influxdata.com/influxdb.key || cube_check_return)" || cube_check_return
#     printf '%s' "${cube_app_tmp}" | apt-key add - || cube_check_return
#     if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_UBUNTU}; then
#       . /etc/lsb-release || cube_check_return
#       echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | tee /etc/apt/sources.list.d/influxdb.list || cube_check_return
#     elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
#       . /etc/os-release || cube_check_return
#       test $VERSION_ID = "7" && echo "deb https://repos.influxdata.com/debian wheezy stable" | tee /etc/apt/sources.list.d/influxdb.list || cube_check_return
#       test $VERSION_ID = "8" && echo "deb https://repos.influxdata.com/debian jessie stable" | tee /etc/apt/sources.list.d/influxdb.list || cube_check_return
#     fi
#     cube_package update
#   fi
else
  cube_throw Not implemented
fi

# Commonly useful commands installed below and described here:

# Test bandwidth:
# * On target, run `firewall-cmd --zone=public --add-port=5001/tcp` and `iperf -s`
# * On client, run `iperf -c ${HOST}`

# Speedtest: `speedtest-cli`

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package install multitail strace htop mtr traceroute patch atop sysstat \
                        iotop gdb bind-utils python sendmail make mailx \
                        postfix tcpdump cyrus-sasl-plain rsyslog gnupg \
                        kexec-tools lzo lzo-devel lzo-minilzo bison bison-devel \
                        ncurses ncurses-devel telnet iftop git \
                        nmap-ncat java-latest-openjdk grub2-tools libffi-devel \
                        file-devel iperf speedtest-cli cronie bc python3-devel \
                        python3-pip ffmpeg chrony p7zip tree ncdu
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  # https://wiki.ubuntu.com/Kernel/CrashdumpRecipe
  # https://help.ubuntu.com/lts/serverguide/kernel-crash-dump.html

  cube_package install multitail strace htop mtr traceroute patch atop sysstat \
                        iotop gdb ldap-utils ntp python make mailutils \
                        postfix tcpdump rsyslog gnupg makedumpfile libsasl2-modules \
                        kexec-tools liblzo2-2 liblzo2-dev libbison-dev \
                        libncurses-dev telnet iftop git \
                        netcat-openbsd default-jdk `uname -r`-dbg crash \
                        libmagic-dev iperf speedtest-cli bc python3-dev \
                        python3-pip python3-lockfile python3-packaging \
                        python3-progress python3-retrying python3-cachecontrol \
                        ffmpeg

  # No need to get upgrade notifications
  if cube_file_exists "/etc/cron.weekly/update-notifier-common"; then
    cube_package_uninstall update-notifier-common
  fi

  cube_read_stdin cubevar_app_kdump_tools <<'HEREDOC'
USE_KDUMP=1
HEREDOC

  cube_set_file_contents_string /etc/default/kdump-tools "${cubevar_app_kdump_tools}"
  
  cube_package autoremove || cube_check_return
else
  cube_throw Not implemented
fi

#if ! pip3 show certbot-dns-digitalocean &>/dev/null; then
#  pip3 install certbot-dns-digitalocean ndg-httpsclient || cube_check_return
#fi

cube_service enable atop
cube_service start atop

mkdir -p /var/lib/rsyslog

if cube_set_file_contents "/etc/rsyslog.conf" "templates/rsyslog.conf" ; then
  # Some servers have a different syslog config, so don't update syslog immediately
  cubevar_api_post_restart=$(cube_append_str "${cubevar_api_post_restart}" "rsyslog")
fi

# if cube_service_exists kdump ; then
#   cube_set_file_contents "/etc/kdump.conf" "templates/kdump.conf"
#
#   # Don't auto-start because we may not have crashkernel yet
#   #cube_service enable kdump
# fi
#
# cube_echo "Total memory (MB): $(cube_total_memory MB), Required for crash kernel: ${cubevar_min_mem_crash_kernel}"
#
# # We can't afford a crash kernel on a tiny server
# if [ $(cube_total_memory MB) -gt ${cubevar_min_mem_crash_kernel} ]; then
#   cube_echo "Ensuring crash kernel"
#
#   # https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html-single/Kernel_Crash_Dump_Guide/index.html#sect-kdump-memory-requirements
#   # 160 MB + 2 bits for every 4 KB of RAM. For a system with 1 TB of memory, 224 MB is the minimum (160 + 64 MB).
#   cubevar_app_crashkernel_mem=$((161+($(cube_total_memory)/268435456)))
#
#   if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA} && [ $(cube_operating_system_version_major) -gt 33 ]; then
#     cube_echo "Checking for crashkernel"
#     if ! ( grubby --info=ALL | cube_stdin_contains "crashkernel" ) ; then
#       cube_echo "crashkernel not found"
#       #grubby --update-kernel=ALL "--args=no_timer_check console=hvc0 LANG=en_US.UTF-8 crashkernel=${cubevar_app_crashkernel_mem}M audit=0" || cube_check_return
#     fi
#   elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA} && [ $(cube_operating_system_version_major) -gt 29 ]; then
#     if cube_set_file_contents "/etc/default/grub" "templates/grub2.template" ; then
#       /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg || cube_check_return
#
#       # https://docs.fedoraproject.org/en-US/Fedora/25/html/System_Administrators_Guide/sec-Making_Persistent_Changes_to_a_GRUB_2_Menu_Using_the_grubby_Tool.html
#       # https://docs.fedoraproject.org/en-US/Fedora/25/html/System_Administrators_Guide/sec-Customizing_the_GRUB_2_Configuration_File.html
#       # grubby --info=ALL
#       # grubby --default-index
#       # grubby --set-default /boot/vmlinuz...
#       # /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
#     fi
#   elif cube_file_exists /boot/extlinux/extlinux.conf ; then
#     sed -i "s/UTF-8\$/UTF-8 crashkernel=${cubevar_app_crashkernel_mem}M audit=0/g" /boot/extlinux/extlinux.conf || cube_check_return
#   elif cube_file_exists /boot/grub/grub.cfg ; then
#     if cube_set_file_contents "/etc/default/grub" "templates/grub1.template" ; then
#       update-grub || cube_check_return
#     fi
#     if cube_set_file_contents "/etc/default/grub.d/kexec-tools.cfg" "templates/kexec-tools.cfg.template" ; then
#       update-grub || cube_check_return
#
#       # For some reason, a reboot is required to pick up the new config
#       # https://cloud.digitalocean.com/support/tickets/1349141
#       cube_error_echo "Updating grub requires a hard shutdown and reboot. Shutting down in 1 minute. Go into the console to power it back on."
#       shutdown -h +1
#       exit 0
#     fi
#   fi
# fi

cube_ensure_directory ~/.ssh/ 700
cube_ensure_file ~/.ssh/authorized_keys 700

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package update
  #cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo update
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  cube_package update
  cube_package upgrade
  cube_package dist-upgrade
else
  cube_throw Not implemented
fi

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA} && [ $(cube_operating_system_version_major) -gt 33 ]; then
  cube_service enable chronyd
  cube_service start chronyd
else
  if cube_service_exists ntpd ; then
    cube_service enable ntpd
    cube_service start ntpd
  else
    cube_service enable ntp
    cube_service start ntp
  fi
fi

cube_set_file_contents "/etc/security/limits.conf" "templates/limits.conf"

cube_set_file_contents ~/.toprc "templates/toprc"

# # crash is already in the debian repos
# if [ $(cube_total_memory MB) -gt ${cubevar_min_mem_crash_kernel} ]; then
#   if ! cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN} ; then
#     if ! cube_file_exists /usr/local/src/crash/crash ; then
#       cube_pushd /usr/local/src/
#       rm -rf crash* || cube_check_return
#       git clone https://github.com/crash-utility/crash/ || cube_check_return
#       cd crash || cube_check_return
#       echo '-DLZO' > CFLAGS.extra || cube_check_return
#       echo '-llzo2' > LDFLAGS.extra || cube_check_return
#       make || cube_check_return
#       cube_popd
#     fi
#   fi
# fi

#if ! cube_has_role "syslog_server" ; then
  # tcpdump -Xvi any port 514
  #if cube_set_file_contents "/etc/rsyslog.d/01-client.conf" "templates/rsyslog_client.conf.template" ; then
  #  cube_service restart rsyslog
  #fi
#fi

cube_include nfs_client false

if cube_set_file_contents "/etc/systemd/system/tcpdump.service" "templates/tcpdump.service.template" ; then
  cube_service daemon-reload
  #cube_service enable tcpdump
  #cube_service restart tcpdump
fi

cube_set_file_contents "/etc/hosts" "templates/hosts.template"

if cube_set_file_contents "/opt/basics.sh" "templates/basics.sh" ; then
  chmod a+x /opt/basics.sh || cube_check_return
fi

if cube_set_file_contents "/etc/cron.daily/basics" "templates/dailycron_basics" ; then
  chmod a+x /etc/cron.daily/basics || cube_check_return
fi

systemctl disable dnf-makecache

true
