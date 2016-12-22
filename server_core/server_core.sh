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

# Machines may be memory constrained, so disable crons for the duration
# of the chef-client run. Re-enable in the server_finish cookbook
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

cube_package install python python-dnf multitail htop lsof wget

cube_package --enablerepo fedora-debuginfo --enablerepo updates-debuginfo install kernel-debuginfo-common-x86_64 kernel-debuginfo glibc-debuginfo-common glibc-debuginfo systemtap perf

if cube_set_file_contents "/var/chef/cache/cookbooks/dnf/libraries/dnf-query.py" "templates/dnf-query.py" ; then
  chmod 755 "/var/chef/cache/cookbooks/dnf/libraries/dnf-query.py" || cube_check_return
fi

cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"
[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/7Server/\$basearch/stable
enabled = 1
gpgcheck = 0
gpgkey = https://repos.influxdata.com/influxdb.key
HEREDOC

cube_set_file_contents_string "/etc/yum.repos.d/influxdb.repo" "${cubevar_app_str}"

cube_check_dir_exists "/etc/cron.d" && cube_service start crond
