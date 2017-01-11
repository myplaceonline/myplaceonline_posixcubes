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

cube_include firewall_whitelist

# Machines may be memory constrained, so disable crons for the duration
# of the chef-client run. Re-enable in the core_end cube
if cube_service_exists crond ; then
  cube_service stop crond
elif cube_service_exists cron ; then
  cube_service stop cron
fi

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN} ; then
  cube_package update
  cube_package install selinux-utils
fi

# Ensure permissive selinux
if cube_dir_exists "/etc/selinux/" && cube_set_file_contents "/etc/selinux/config" "templates/selinux_config" && [ "$(getenforce)" != "Disabled" ] ; then
  setenforce Permissive || cube_check_return
fi

# We set a user password in the case we need to do a manual login from the web console
echo "root:${cubevar_app_passwords_root}" | chpasswd

#cube_set_file_contents_string ~/.passwd ${cubevar_app_passwords_root}
#passwd --stdin root < ~/.passwd || cube_check_return
#rm -f ~/.passwd

if cube_set_file_contents "/etc/commonprofile.sh" "templates/commonprofile.sh" ; then
  chmod 755 "/etc/commonprofile.sh" || cube_check_return
  cube_set_file_contents "/etc/profile" "templates/profile"
fi

cube_set_file_contents_string "/etc/motd" "${cubevar_app_motd}"

if cube_set_file_contents "/etc/sysctl.conf" "templates/sysctl.conf" ; then
  sysctl -p || cube_check_return
fi

if cube_set_file_contents "/etc/systemd/journald.conf" "templates/journald.conf" ; then
  cube_service restart systemd-journald
fi

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package install python python-dnf multitail htop lsof wget nfs-utils at
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  cube_package install python multitail htop lsof wget nfs-common at apt-transport-https
else
  cube_throw Not implemented
fi

cube_service enable atd
cube_service start atd

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo install kernel-debuginfo-common-x86_64 kernel-debuginfo glibc-debuginfo-common glibc-debuginfo systemtap perf
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
      apt-get update || cube_check_return

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
  cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"
[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/7Server/\$basearch/stable
enabled = 1
gpgcheck = 0
gpgkey = https://repos.influxdata.com/influxdb.key
HEREDOC

  cube_set_file_contents_string "/etc/yum.repos.d/influxdb.repo" "${cubevar_app_str}"

  cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"
[logstash-5.x]
name=Elastic repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
HEREDOC

  cube_set_file_contents_string "/etc/yum.repos.d/logstash.repo" "${cubevar_app_str}"
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  if ! cube_file_exists /etc/apt/sources.list.d/elastic-5.x.list ; then
    cube_app_tmp="$(wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch || cube_check_return)" || cube_check_return
    printf '%s' "${cube_app_tmp}" | apt-key add - || cube_check_return
    echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-5.x.list || cube_check_return
    cube_package update
  fi
  
  if ! cube_file_exists /etc/apt/sources.list.d/influxdb.list ; then
    cube_app_tmp="$(curl -sL https://repos.influxdata.com/influxdb.key || cube_check_return)" || cube_check_return
    printf '%s' "${cube_app_tmp}" | apt-key add - || cube_check_return
    if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_UBUNTU}; then
      . /etc/lsb-release || cube_check_return
      echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | tee /etc/apt/sources.list.d/influxdb.list || cube_check_return
    elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
      . /etc/os-release || cube_check_return
      test $VERSION_ID = "7" && echo "deb https://repos.influxdata.com/debian wheezy stable" | tee /etc/apt/sources.list.d/influxdb.list || cube_check_return
      test $VERSION_ID = "8" && echo "deb https://repos.influxdata.com/debian jessie stable" | tee /etc/apt/sources.list.d/influxdb.list || cube_check_return
    fi
    cube_package update
  fi
else
  cube_throw Not implemented
fi

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package install multitail strace htop mtr traceroute patch atop sysstat \
                        iotop gdb bind-utils ntp python sendmail make mailx \
                        postfix tcpdump cyrus-sasl-plain rsyslog gnupg \
                        kexec-tools lzo lzo-devel lzo-minilzo bison bison-devel \
                        ncurses ncurses-devel telegraf telnet iftop git \
                        nmap-ncat java-1.8.0-openjdk grub2-tools
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  # https://wiki.ubuntu.com/Kernel/CrashdumpRecipe
  # https://help.ubuntu.com/lts/serverguide/kernel-crash-dump.html

  cube_package install multitail strace htop mtr traceroute patch atop sysstat \
                        iotop gdb ldap-utils ntp python make mailutils \
                        postfix tcpdump rsyslog gnupg makedumpfile libsasl2-modules \
                        kexec-tools liblzo2-2 liblzo2-dev libbison-dev \
                        libncurses-dev telegraf telnet iftop git \
                        netcat-openbsd default-jdk `uname -r`-dbg crash

  cube_read_heredoc <<'HEREDOC'; cubevar_app_kdump_tools="${cube_read_heredoc_result}"
USE_KDUMP=1
HEREDOC

  cube_set_file_contents_string /etc/default/kdump-tools "${cubevar_app_kdump_tools}"
else
  cube_throw Not implemented
fi

cube_service enable atop
cube_service start atop

if cube_set_file_contents "/etc/rsyslog.conf" "templates/rsyslog.conf" ; then
  # Some servers have a different syslog config, so don't update syslog immediately
  cubevar_api_post_restart=$(cube_append_str "${cubevar_api_post_restart}" "rsyslog")
fi

if cube_service_exists kdump ; then
  cube_set_file_contents "/etc/kdump.conf" "templates/kdump.conf"

  # Don't auto-start because we may not have crashkernel yet
  cube_service enable kdump
fi

# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html-single/Kernel_Crash_Dump_Guide/index.html#sect-kdump-memory-requirements
# 160 MB + 2 bits for every 4 KB of RAM. For a system with 1 TB of memory, 224 MB is the minimum (160 + 64 MB).
cubevar_app_crashkernel_mem=$((161+($(cube_total_memory)/268435456)))

if cube_file_exists /boot/extlinux/extlinux.conf ; then
  sed -i "s/UTF-8\$/UTF-8 crashkernel=${cubevar_app_crashkernel_mem}M audit=0/g" /boot/extlinux/extlinux.conf || cube_check_return
elif cube_file_exists /boot/grub/grub.cfg ; then
  if cube_set_file_contents "/etc/default/grub" "templates/grub1.template" ; then
    update-grub || cube_check_return
  fi
  if cube_set_file_contents "/etc/default/grub.d/kexec-tools.cfg" "templates/kexec-tools.cfg.template" ; then
    update-grub || cube_check_return
    
    # For some reason, a reboot is required to pick up the new config
    # https://cloud.digitalocean.com/support/tickets/1349141
    cube_error_echo "Updating grub requires a hard shutdown and reboot. Shutting down in 1 minute. Go into the console to power it back on."
    shutdown -h +1
    exit 0
  fi
else
  # https://docs.fedoraproject.org/en-US/Fedora/25/html/System_Administrators_Guide/sec-Making_Persistent_Changes_to_a_GRUB_2_Menu_Using_the_grubby_Tool.html
  # https://docs.fedoraproject.org/en-US/Fedora/25/html/System_Administrators_Guide/sec-Customizing_the_GRUB_2_Configuration_File.html
  # grubby --update-kernel=ALL "--args=no_timer_check console=hvc0 LANG=en_US.UTF-8 crashkernel=${cubevar_app_crashkernel_mem}M audit=0" || cube_check_return

  if cube_set_file_contents "/etc/default/grub" "templates/grub2.template" ; then
    /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg || cube_check_return
  fi
fi

cube_ensure_directory ~/.ssh/ 700
cube_ensure_file ~/.ssh/authorized_keys 700

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_package update
  cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo update
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  cube_package update
  cube_package upgrade
else
  cube_throw Not implemented
fi

if cube_service_exists ntpd ; then
  cube_service enable ntpd
  cube_service start ntpd
else
  cube_service enable ntp
  cube_service start ntp
fi

cubevar_app_hostname=$(cube_hostname)

# To test sending mail from the box:
#   echo "Message body" | mail -s "Subject" -r from@example.com to@example.com
if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
  cube_set_file_contents "/etc/postfix/main.cf" "templates/main.cf.fedora.template"
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
  cube_set_file_contents_string "/etc/mailname" "myplaceonline.com"
  cube_set_file_contents "/etc/postfix/main.cf" "templates/main.cf.debian.template"
else
  cube_throw Not implemented
fi

cube_service enable postfix
cube_service start postfix

cube_set_file_contents "/etc/security/limits.conf" "templates/limits.conf"

cube_set_file_contents ~/.toprc "templates/toprc"

if ! cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN} ; then
  if ! cube_file_exists /usr/local/src/crash/crash ; then
    cube_pushd /usr/local/src/
    rm -rf crash* || cube_check_return
    git clone https://github.com/crash-utility/crash/ || cube_check_return
    cd crash || cube_check_return
    echo '-DLZO' > CFLAGS.extra || cube_check_return
    echo '-llzo2' > LDFLAGS.extra || cube_check_return
    make || cube_check_return
    cube_popd
  fi
fi

if ! cube_has_role "syslog_server" ; then
  # tcpdump -Xvi any port 514
  if cube_set_file_contents "/etc/rsyslog.d/01-client.conf" "templates/rsyslog_client.conf.template" ; then
    cube_service restart rsyslog
  fi
fi
