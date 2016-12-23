#!/bin/sh

# Ruby uses a lot of memory, so first stop weighty processes. Wrap in a sub-shell to eat any exceptions (e.g. if
# first setting up the box and the service doesn't exist)
(cube_service stop nginx) 2>/dev/null
cube_service restart rsyslog

cube_package install nginx ruby rubygems ruby-devel redhat-rpm-config gnupg ImageMagick ImageMagick-c++ ImageMagick-c++-devel ImageMagick-devel ImageMagick-libs golang git gcc gcc-c++ openssl-devel postgresql-devel postgresql nodejs libcurl-devel

if cube_set_file_contents "/usr/lib/systemd/system/nginx.service" "templates/nginx.service.template" ; then
  cube_service daemon-reload
fi

if ! cube_check_file_exists "/opt/nginx-${cubevar_app_nginx_source_version}/sbin/nginx" ; then
  # Install nginx

  #mkdir ${cubevar_app_nginx_passenger_root}ext || cube_check_return
  #ln -s ${cubevar_app_nginx_passenger_root}src/nginx_module ${cubevar_app_nginx_passenger_root}ext/nginx || cube_check_return
  true
fi

if cube_set_file_contents "/etc/telegraf/telegraf.conf" "templates/telegraf.conf.template" ; then
  cube_service restart telegraf
fi

cube_service enable telegraf
cube_service start telegraf

usermod -a -G webgrp root || cube_check_return

cube_ensure_directory "${cubevar_app_web_dir}" 755 ${USER} webgrp

cube_pushd "${cubevar_app_web_dir}"

if ! cube_check_dir_exists "${cubevar_app_web_dir}/.git" ; then
  git clone "https://github.com/myplaceonline/myplaceonline_rails" || cube_check_return
else
  cd "${cubevar_app_web_dir}/" || cube_check_return
  git pull origin master || cube_check_return
fi

cube_popd

cube_read_heredoc <<HEREDOC; cubevar_app_passenger_status="${cube_read_heredoc_result}"
#!/bin/sh
PASSENGER_INSTANCE_REGISTRY_DIR=/var/run/ /usr/local/share/gems/gems/passenger-${cubevar_app_nginx_passenger_version}/bin/passenger-status -v --show=xml
HEREDOC

if cube_set_file_contents_string "/usr/local/share/gems/gems/passenger-${cubevar_app_nginx_passenger_version}/bin/passenger_status.sh" "${cubevar_app_passenger_status}" ; then
  chmod 755 "/usr/local/share/gems/gems/passenger-${cubevar_app_nginx_passenger_version}/bin/passenger_status.sh"
fi

cube_set_file_contents "/etc/nginx/conf.d/passenger.conf" "templates/passenger.conf.template"

cube_ensure_file "${cubevar_app_web_dir}/log/passenger.log" 666

cube_set_file_contents "/etc/nginx/nginx.conf" "templates/nginx_core.conf.template"

cubevar_app_eth1=$(cube_interface_ipv4_address eth1) || cube_check_return
cubevar_app_hostname=$(cube_hostname) || cube_check_return
cubevar_app_hostname_simple=$(cube_hostname "true") || cube_check_return
cubevar_app_source_revision=$(git --git-dir "${cubevar_app_web_dir}/.git" rev-parse HEAD) || cube_check_return

cubevar_app_trusted_servers=""
for cubevar_app_web_server in ${cubevar_app_web_servers}; do
  cubevar_app_server_internal=$(echo "${cubevar_app_web_server}" | sed 's/\./-internal./')
  cubevar_app_trusted_servers=$(cube_append_str "${cubevar_app_trusted_servers}" "${cubevar_app_server_internal}" ";")
done

if cube_set_file_contents "${cubevar_app_nginx_dir}/sites-available/${cubevar_app_name}.conf" "templates/nginx.conf.template" ; then
  chmod 644 "${cubevar_app_nginx_dir}/sites-available/${cubevar_app_name}.conf"
fi

cube_ensure_directory "${cubevar_app_web_dir}/tmp/"
chmod -R 777 "${cubevar_app_web_dir}/tmp/" || cube_check_return
cube_ensure_directory "${cubevar_app_web_dir}/tmp/myp/" 777
cube_ensure_directory "${cubevar_app_web_dir}/log/" 777
cube_ensure_file "${cubevar_app_web_dir}/log/production.log"
chmod 666 "${cubevar_app_web_dir}/log/production.log" || cube_check_return

if cube_set_file_contents "${cubevar_app_web_dir}/config/database.yml" "templates/database.yml.template" ; then
  chmod 700 "${cubevar_app_web_dir}/config/database.yml" || cube_check_return
  # database.yml is read within the context of Passenger, not nginx
  chown nobody "${cubevar_app_web_dir}/config/database.yml" || cube_check_return
fi

if [ "$(gem list bundler -i)" != "true" ]; then
  gem install bundler -q --no-rdoc --no-ri || cube_check_return
fi

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
  
  cube_echo "Running bundle install"
  
  bin/bundle install --deployment || cube_check_return
  
  if [ "$(psql -tA -U ${cubevar_app_db_dbuser} -h ${cubevar_app_db_host} -d ${cubevar_app_db_dbname} -c "\\dt" | grep -c "No relations found.")" != "0" ]; then
    # This is a major operation, so just in case there's some freak reason the previous command didn't work, prompt
    if cube_prompt "DESTRUCTIVE: Drop and re-create database?" ; then
      bin/bundle exec rake db:drop db:create db:schema:load db:seed || cube_check_return
    fi
  fi
  
  cube_echo "Running db:migrate"
  
  bin/bundle exec rake db:migrate || cube_check_return

  cube_echo "Running assets:precompile"
  
  bin/bundle exec rake assets:precompile || cube_check_return
  
) || cube_check_return

cube_popd

#nginx_site "#{node.app.name}.conf" do
#  enable true
#end

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

cube_service start nginx

cube_echo "Initializing with curl"

curl -s "http://${cubevar_app_hostname_simple}-internal.myplaceonline.com/" > /dev/null
