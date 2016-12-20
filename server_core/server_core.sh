#!/bin/sh
cat <<'HEREDOC'

                        _                            _ _            
                       | |                          | (_)           
  _ __ ___  _   _ _ __ | | __ _  ___ ___  ___  _ __ | |_ _ __   ___ 
 | '_ ` _ \| | | | '_ \| |/ _` |/ __/ _ \/ _ \| '_ \| | | '_ \ / _ \
 | | | | | | |_| | |_) | | (_| | (_|  __/ (_) | | | | | | | | |  __/
 |_| |_| |_|\__, | .__/|_|\__,_|\___\___|\___/|_| |_|_|_|_| |_|\___|
             __/ | |                                                
            |___/|_|                                                



HEREDOC

# Description:
#   Set system timezone to $1
# Example call:
#   cube_set_timezone UTC
# Arguments:
#   Required:
#     $1: Relative time zone path under /usr/share/zoneinfo/
cube_set_timezone() {
  cube_check_numargs 1 "${@}"
  ! cube_check_file_exists /usr/share/zoneinfo/${1} && cube_throw "Time zone doesn't exist"
  ln -sf /usr/share/zoneinfo/${1} /etc/localtime || cube_check_return
  return 0
}

cube_set_timezone UTC

df -h | grep -v tmpfs
echo ""
free -m
echo ""
cat /proc/cpuinfo | grep -e processor -e MHz
echo ""
grep -e MemTotal -e MemFree -e Buffers -e ^Cached /proc/meminfo
echo ""

# Machines may be memory constrained, so disable crons for the duration
# of the chef-client run. Re-enable in the server_finish cookbook
cube_check_dir_exists "/etc/cron.d" && cube_service stop crond

# Ensure permissive selinux
if cube_set_file_contents "/etc/selinux/config" "templates/selinux_config" ; then
  setenforce Permissive || cube_check_return
fi

cube_check_dir_exists "/etc/cron.d" && cube_service start crond
