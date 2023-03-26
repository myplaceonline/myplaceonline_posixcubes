#!/bin/sh

cube_service restart rsyslog

if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then

  # https://yarnpkg.com/lang/en/docs/install/
  cube_read_stdin cubevar_app_str <<'HEREDOC'
[yarn]
name=Yarn Repository
baseurl=https://dl.yarnpkg.com/rpm/
enabled=1
gpgcheck=1
gpgkey=https://dl.yarnpkg.com/rpm/pubkey.gpg
HEREDOC

  cube_set_file_contents_string "/etc/yum.repos.d/yarn.repo" "${cubevar_app_str}"

  cube_package install ruby rubygems ruby-devel redhat-rpm-config gnupg \
                       ImageMagick ImageMagick-c++ ImageMagick-c++-devel \
                       ImageMagick-devel ImageMagick-libs golang git gcc \
                       gcc-c++ openssl-devel pcre-devel postgresql-devel \
                       postgresql nodejs libcurl-devel httpd yarn libxml2-devel \
                       dovecot libsass-devel libyaml-devel
elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then

  # https://yarnpkg.com/lang/en/docs/install/
  if ! cube_file_exists /etc/apt/sources.list.d/yarn.list ; then
    cube_app_tmp="$(wget -qO - https://dl.yarnpkg.com/debian/pubkey.gpg || cube_check_return)" || cube_check_return
    printf '%s' "${cube_app_tmp}" | apt-key add - || cube_check_return
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee -a /etc/apt/sources.list.d/yarn.list || cube_check_return
    cube_package update
  fi

  cube_package install ruby rubygems ruby-dev gnupg \
                       imagemagick libmagickwand-dev \
                       golang git gcc build-essential \
                       g++ libssl-dev libpcre3-dev libpcre++-dev libpq-dev \
                       postgresql nodejs libcurl4-openssl-dev apache2 yarn libxml2-dev \
                       dovecot libyaml-dev
  
  cube_service disable apache2
  cube_service stop apache2

  cube_service disable postgresql
  cube_service stop postgresql
fi

cube_ensure_directory "${cubevar_app_nfs_client_mount}/uploads/" 777

if cube_set_file_contents "/usr/lib/systemd/system/nginx.service" "templates/nginx.service.template" ; then
  cube_service daemon-reload
fi

cubevar_nginx_root="${cubevar_nginx_root}/nginx-${cubevar_app_nginx_source_version}"

if [ "${cubevar_nginx_reinstall}" = "1" ]; then
  rm -rf "${cubevar_nginx_root}"
fi

if ! cube_dir_exists "${cubevar_nginx_root}" ; then

  cube_echo "Installing nginx ${cubevar_app_nginx_source_version}"

  if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
    cube_package install autoconf bison flex gcc gcc-c++ gettext kernel-devel \
                         make m4 ncurses-devel patch zlib-devel gc pcre-devel \
                         zlib-devel wget openssl-devel libxml2-devel \
                         libxslt-devel gd-devel perl-ExtUtils-Embed \
                         GeoIP-devel gperftools gperftools-devel \
                         libatomic_ops-devel
  elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
    cube_package install autoconf bison flex gcc g++ gettext \
                         make m4 patch libpcre3-dev libxml2-dev \
                         zlib1g-dev libncurses5-dev wget libcurl4-openssl-dev \
                         libxslt-dev libgd2-xpm-dev perl-modules \
                         libgeoip-dev build-essential google-perftools \
                         libgoogle-perftools-dev libatomic-ops-dev \
                         linux-headers-$(uname -r)
  fi

  rm -rf /usr/local/src/nginx-${cubevar_app_nginx_source_version}* 2>/dev/null
  wget -O "/usr/local/src/nginx-${cubevar_app_nginx_source_version}.tar.gz" "https://nginx.org/download/nginx-${cubevar_app_nginx_source_version}.tar.gz" || cube_check_return
  
  if ! cube_user_exists nginx ; then
    cube_create_user nginx /sbin/nologin
    if ! cube_group_exists nginx ; then
      cube_create_group nginx
    fi
    if ! cube_group_contains_user nginx nginx ; then
      cube_add_group_user nginx nginx true
    fi
  fi
  
  cube_echo "Cloning nginx-upload-module"
  (
    cd /usr/local/src/ || cube_check_return
    rm -rf /usr/local/src/nginx-upload-module 2>/dev/null
    git clone -b passformfieldsissue https://github.com/myplaceonline/nginx-upload-module || cube_check_return
  ) || cube_check_return

  cube_pushd "/usr/local/src/"

    tar xzvf "/usr/local/src/nginx-${cubevar_app_nginx_source_version}.tar.gz" || cube_check_return

    cube_pushd "nginx-${cubevar_app_nginx_source_version}"

      # https://www.phusionpassenger.com/library/install/nginx/install_as_nginx_module.html
      # http://nginx.org/en/docs/configure.html

      cube_echo "Installing passenger gem"

      gem install passenger -N || cube_check_return
      
      # https://github.com/phusion/passenger/issues/2189
      #cp /root/Configuration.c /usr/local/share/gems/gems/passenger-6.0.2/src/nginx_module/Configuration.c || cube_check_return
      
      cubevar_app_nginx_srcdir="$(passenger-config --nginx-addon-dir)" || cube_check_return
      
      cube_echo "Compiling nginx with passenger @ ${cubevar_app_nginx_srcdir}"
      
      ./configure --user=nginx --group=nginx --prefix=${cubevar_nginx_root} \
        --with-http_ssl_module --with-pcre --with-http_gzip_static_module \
        --add-module=${cubevar_app_nginx_srcdir} \
        --add-module=/usr/local/src/nginx-upload-module \
        --with-debug \
        || cube_check_return
      
      cube_echo "Compiling nginx"
      
      make || cube_check_return
      
      cube_echo "Installing nginx"
      
      make install || cube_check_return
      
    cube_popd

  cube_popd

  #rm -rf "$(cube_tmpdir)"/nginx-${cubevar_app_nginx_source_version}* 2>/dev/null
fi

cubevar_nginx_passenger_root="$(passenger-config about root)"

# if cube_set_file_contents "/etc/telegraf/telegraf.conf" "templates/telegraf.conf.template" ; then
#   cube_service restart telegraf
# fi
# 
# cube_service enable telegraf
# cube_service start telegraf

if ! cube_group_exists webgrp ; then
  cube_create_group webgrp
fi
if ! cube_group_contains_user webgrp root ; then
  cube_add_group_user webgrp root
fi

cube_ensure_directory "${cubevar_app_web_dir}" 755 ${USER} webgrp

cube_pushd "${cubevar_app_web_dir}"

if ! cube_dir_exists "${cubevar_app_web_dir}/.git" ; then
  git clone "https://github.com/myplaceonline/myplaceonline_rails" . || cube_check_return
else
  git pull origin master || cube_check_return
fi

if ! cube_dir_exists "${cubevar_app_web_dir}/engines/" ; then
  mkdir "${cubevar_app_web_dir}/engines/"
fi

clone_update_engine() {
  if [ "$1" != "" ]; then
    if ! cube_dir_exists "${cubevar_app_web_dir}/engines/$2" ; then
      git clone "https://oauth2:${cubevar_app_gitlab_token}@gitlab.com/$1" "${cubevar_app_web_dir}/engines/$2" || cube_check_return
    fi

    cube_pushd "${cubevar_app_web_dir}/engines/$2"
    git pull || cube_check_return
    cube_popd
  fi
}

clone_update_engine "${cubevar_app_gitlab_engine_path1_repo}" "${cubevar_app_gitlab_engine_path1_dir}"
clone_update_engine "${cubevar_app_gitlab_engine_path2_repo}" "${cubevar_app_gitlab_engine_path2_dir}"
clone_update_engine "${cubevar_app_gitlab_engine_path3_repo}" "${cubevar_app_gitlab_engine_path3_dir}"

# for i in ${cubevar_app_web_dir}/engines/*; do
#   (
#     cube_echo "Updating engine ${i}"
#     cube_pushd ${i}
#     git pull || cube_check_return
#     cube_popd
#   )
# done

if [ "${cubevar_app_gitlab_engine_config_path}" != "" ]; then
  if ! cube_dir_exists "${cubevar_app_web_dir}/engines_config/" ; then
    mkdir "${cubevar_app_web_dir}/engines_config/"
    git clone "https://oauth2:${cubevar_app_gitlab_token}@gitlab.com/${cubevar_app_gitlab_engine_config_path}" "${cubevar_app_web_dir}/engines_config/$(basename "${cubevar_app_gitlab_engine_config_path}")" || cube_check_return
    ln -s "${cubevar_app_web_dir}/engines_config/$(basename "${cubevar_app_gitlab_engine_config_path}")/Gemfile_engines.lock" "${cubevar_app_web_dir}/Gemfile_engines.lock" || cube_check_return
  fi
  
  cube_pushd "${cubevar_app_web_dir}/engines_config/$(basename "${cubevar_app_gitlab_engine_config_path}")/"
  git pull || cube_check_return
  cube_popd
fi

if cube_set_file_contents_string "${cubevar_app_web_dir}/config/oidcsigning.pem" "${cubevar_app_oidc_signing_key}" ; then
  chmod 755 "${cubevar_app_web_dir}/config/oidcsigning.pem" || cube_check_return
fi

cube_popd

cube_read_stdin cubevar_app_passenger_status <<HEREDOC
#!/bin/sh
PASSENGER_INSTANCE_REGISTRY_DIR=/var/run/ ${cubevar_nginx_passenger_root}/bin/passenger-status -v --show=xml
HEREDOC

if cube_set_file_contents_string "${cubevar_nginx_passenger_root}/bin/passenger_status.sh" "${cubevar_app_passenger_status}" ; then
  chmod 755 "${cubevar_nginx_passenger_root}/bin/passenger_status.sh"
fi

cube_set_file_contents "${cubevar_nginx_root}/conf/nginx.conf" "templates/nginx_core.conf.template"
cube_set_file_contents "${cubevar_nginx_root}/conf/conf.d/passenger.conf" "templates/passenger.conf.template"

cube_ensure_file "${cubevar_app_web_dir}/log/passenger.log" 666

cubevar_app_eth1=$(cube_interface_ipv4_address eth1) || cube_check_return
cubevar_app_hostname=$(cube_hostname) || cube_check_return
cubevar_app_hostname_simple=$(cube_hostname "true") || cube_check_return
cubevar_app_source_revision=$(git --git-dir "${cubevar_app_web_dir}/.git" rev-parse HEAD) || cube_check_return

cubevar_app_trusted_servers=""
for cubevar_app_web_server in ${cubevar_app_web_servers}; do
  cubevar_app_server_internal=$(echo "${cubevar_app_web_server}" | sed 's/\./-internal./')
  cubevar_app_trusted_servers=$(cube_append_str "${cubevar_app_trusted_servers}" "${cubevar_app_server_internal}" ";")
done

if cube_set_file_contents "${cubevar_nginx_root}/conf/sites-enabled/${cubevar_app_name}.conf" "templates/nginx.conf.template" ; then
  chmod 644 "${cubevar_nginx_root}/conf/sites-enabled/${cubevar_app_name}.conf"
fi

cube_ensure_directory "${cubevar_app_web_dir}/tmp/"
chmod -R 777 "${cubevar_app_web_dir}/tmp/" || cube_check_return
cube_ensure_directory "${cubevar_app_web_dir}/tmp/myp/" 777
cube_ensure_directory "${cubevar_app_web_dir}/tmp/cache/" 777
cube_ensure_directory "${cubevar_app_web_dir}/tmp/cache/bootsnap/" 777
chmod -R 777 "${cubevar_app_web_dir}/tmp/cache/bootsnap"*
cube_ensure_directory "${cubevar_app_web_dir}/log/" 777
cube_ensure_file "${cubevar_app_web_dir}/log/production.log"
chmod 666 "${cubevar_app_web_dir}/log/production.log" || cube_check_return

if cube_set_file_contents "${cubevar_app_web_dir}/config/database.yml" "templates/database.yml.template" ; then
  chmod 700 "${cubevar_app_web_dir}/config/database.yml" || cube_check_return
  # database.yml is read within the context of Passenger, not nginx
  chown nobody "${cubevar_app_web_dir}/config/database.yml" || cube_check_return
fi

# if [ "$(gem list bundler -i -v 2.2.17)" != "true" ]; then
#   gem install bundler:2.2.17 -q || cube_check_return
# fi

if cube_set_file_contents ~/.pgpass "templates/pgpass.template" ; then
  chmod 700 ~/.pgpass
fi

cube_pushd "${cubevar_app_web_dir}"

(
  export RAILS_ENV="${cubevar_app_rails_environment}"
  export SECRET_KEY_BASE="${cubevar_app_passwords_devise_secret}"
  export ROOT_EMAIL="${cubevar_app_root_email}"
  export ROOT_PASSWORD="${cubevar_app_passwords_rails_root}"
  export FTS_TARGET="${cubevar_app_full_text_search_target}"
  export RUBY_GC_MALLOC_LIMIT_MAX="${cubevar_app_rails_gc_max_newspace}"
  export RUBY_GC_OLDMALLOC_LIMIT_MAX="${cubevar_app_rails_gc_max_oldspace}"
  export BUNDLE_GEMFILE="${cubevar_app_rails_gemfile}"
  export MIGRATING=true
  
  cube_echo "Running bundle install"

  # bin/bundle exec gem uninstall rmagick
  #bin/bundle config set --local deployment 'false' || cube_check_return
  bin/bundle install || cube_check_return

  if [ -d "/usr/share/gems/gems/mail-2.8.0" ]; then
    chmod -R a+r /usr/share/gems/gems/mail-2.8.0
  fi
  
  if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
    if cube_file_exists /var/www/html/myplaceonline/vendor/bundle/ruby/2.6.0/gems/sassc-2.2.0/ext/libsass.so ; then
      if ! cube_file_exists /var/www/html/myplaceonline/vendor/bundle/ruby/2.6.0/gems/sassc-2.2.0/lib/sassc/libsass.so ; then
        sudo ln -s /var/www/html/myplaceonline/vendor/bundle/ruby/2.6.0/gems/sassc-2.2.0/ext/libsass.so /var/www/html/myplaceonline/vendor/bundle/ruby/2.6.0/gems/sassc-2.2.0/lib/sassc/libsass.so || cube_check_return
      fi
    elif cube_file_exists /var/www/html/myplaceonline/vendor/bundle/ruby/3.0.0/extensions/x86_64-linux/3.0.0/sassc-2.4.0/sassc/libsass.so ; then
      if ! cube_file_exists /var/www/html/myplaceonline/vendor/bundle/ruby/3.0.0/gems/sassc-2.4.0/lib/sassc/libsass.so ; then
        sudo ln -s /var/www/html/myplaceonline/vendor/bundle/ruby/3.0.0/extensions/x86_64-linux/3.0.0/sassc-2.4.0/sassc/libsass.so /var/www/html/myplaceonline/vendor/bundle/ruby/3.0.0/gems/sassc-2.4.0/lib/sassc/libsass.so || cube_check_return
      fi
    fi
  fi

  cubevar_web_psql_output="$(psql -tA -U ${cubevar_app_db_dbuser} -h ${cubevar_app_db_host} -p ${cubevar_app_db_port} -d ${cubevar_app_db_dbname} -c '\dt')" || cube_check_return
  
  if [ "$(echo "${cubevar_web_psql_output}" | grep -c "No relations found.")" != "0" ]; then
    # This is a major operation, so just in case there's some freak reason the previous command didn't work, prompt
    if cube_prompt "DESTRUCTIVE: Drop and re-create database?" ; then
      bin/bundle exec rake db:drop db:create db:schema:load db:seed || cube_check_return
    fi
  fi
  
  cube_echo "Finding migrations from engines"
  
  for i in ${cubevar_app_web_dir}/engines/*; do
  (
    for j in "${i}/db/migrate/"*; do
      cp -u "${j}" "${cubevar_app_web_dir}/db/migrate/$(basename "${j}" .rb).$(basename "${i}").rb" || cube_check_return
    done
  )
  done

  cube_echo "Running db:migrate"
  
  bin/rails db:migrate || cube_check_return

  cube_echo "Running assets:precompile"
  
  bin/rails assets:precompile || cube_check_return
  
) || cube_check_return

cube_popd

if cube_set_file_contents_string ~/.irbrc "IRB.conf[:PROMPT_MODE] = :SIMPLE" ; then
  chmod 700 ~/.irbrc
fi

if cube_set_file_contents "/var/spool/cron/root" "templates/crontab.template" ; then
  chmod 600 "/var/spool/cron/root"
fi

if cube_set_file_contents "/etc/systemd/system/myplaceonline-delayedjobs.service" "templates/myplaceonline-delayedjobs.service.template" ; then
  cube_service daemon-reload
  cube_service enable myplaceonline-delayedjobs
fi

# Always restart the job to pick up the latest rails source code
cube_service restart myplaceonline-delayedjobs

if cube_set_file_contents "/opt/myplaceonline/myplaceonline-nginx-ready.sh" "templates/myplaceonline-nginx-ready.sh.template" ; then
  chmod 755 /opt/myplaceonline/myplaceonline-nginx-ready.sh
fi

# if cube_set_file_contents "/etc/systemd/system/myplaceonline-nginx-ready.service" "templates/myplaceonline-nginx-ready.service" ; then
#   cube_service daemon-reload
#   cube_service enable myplaceonline-nginx-ready
#   cube_service start myplaceonline-nginx-ready
# fi

cube_service enable nginx
cube_service start nginx

if cube_set_file_contents "/etc/cron.daily/webstats" "templates/dailycron_webstats" ; then
  chmod a+x /etc/cron.daily/webstats || cube_check_return
fi

# Wait for Passenger to initialize all of the handler processes
cube_echo "Waiting ${cubevar_app_nginx_start_wait} seconds for Rails to start"
sleep ${cubevar_app_nginx_start_wait}

app_haproxy_result="$(curl -s -S -u "admin:${cubevar_app_passwords_haproxy_stats}" -d "s=$(cube_hostname "true")" -d "action=ready" -d "b=#4" -w "%{redirect_url}" "${cubevar_app_passwords_haproxy_url}")" || cube_check_return

app_haproxy_result="$(echo "${app_haproxy_result}" | sed 's/.*;st=//g')"

cube_echo "Disabling maintenance mode on $(cube_hostname "true") result: ${app_haproxy_result}"

true
