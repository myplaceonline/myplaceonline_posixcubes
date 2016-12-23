#!/bin/sh

cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"

                        _                            _ _            
                       | |                          | (_)           
  _ __ ___  _   _ _ __ | | __ _  ___ ___  ___  _ __ | |_ _ __   ___ 
 | '_ ` _ \| | | | '_ \| |/ _` |/ __/ _ \/ _ \| '_ \| | | '_ \ / _ \
 | | | | | | |_| | |_) | | (_| | (_|  __/ (_) | | | | | | | | |  __/
 |_| |_| |_|\__, | .__/|_|\__,_|\___\___|\___/|_| |_|_|_|_| |_|\___|
             __/ | |                                                
            |___/|_|                                                



HEREDOC

echo "${cubevar_app_str}"

# https://www.phusionpassenger.com/library/install/nginx/install_as_nginx_module.html

cuge_package install autoconf bison flex gcc gcc-c++ gettext kernel-devel make m4 ncurses-devel patch zlib-devel

rm -rf "$(cube_tmpdir)"/nginx-${cubevar_app_nginx_source_version}* 2>/dev/null
wget -O "$(cube_tmpdir)/nginx-${cubevar_app_nginx_source_version}.tar.gz" "https://nginx.org/download/nginx-${cubevar_app_nginx_source_version}.tar.gz" || cube_check_return

cube_pushd "$(cube_tmpdir)"

tar xzvf "$(cube_tmpdir)/nginx-${cubevar_app_nginx_source_version}.tar.gz" || cube_check_return

cube_pushd "nginx-${cubevar_app_nginx_source_version}"

gem install passenger || cube_check_return

#./configure 

cube_popd

cube_popd

rm -rf "$(cube_tmpdir)"/nginx-${cubevar_app_nginx_source_version}* 2>/dev/null

true
