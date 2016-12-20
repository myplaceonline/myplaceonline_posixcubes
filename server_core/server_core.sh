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
