#!/bin/sh

# https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-repositories.html
cube_read_stdin cubevar_app_str <<'HEREDOC'
[elasticsearch-5.x]
name=Elasticsearch repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
HEREDOC

cube_set_file_contents_string "/etc/yum.repos.d/elasticsearch.repo" "${cubevar_app_str}"

cube_package install elasticsearch chkconfig

if cube_set_file_contents "/etc/elasticsearch/jvm.options" "templates/elasticsearch_jvm.options.yml" ; then
  mv /usr/lib/systemd/system/elasticsearch.service /etc/systemd/system/
  cube_service daemon-reload
  cube_service restart elasticsearch
fi

cubevar_app_eth1=$(cube_interface_ipv4_address eth1) || cube_check_return

if cube_set_file_contents "/etc/elasticsearch/elasticsearch.yml" "templates/elasticsearch.yml.template" ; then
  cube_service restart elasticsearch
fi

if cube_set_file_contents "/etc/elasticsearch/log4j2.properties" "templates/elasticsearch_log4j2.properties" ; then
  cube_service restart elasticsearch
fi

cube_service enable elasticsearch
cube_service start elasticsearch

#cube_set_file_contents "/etc/logstash/logstash.yml" "templates/logstash.yml"
#
#if cube_set_file_contents "/etc/logstash/jvm.options" "templates/logstash_jvm.options" ; then
#  cube_service restart logstash
#fi

#if cube_set_file_contents "/etc/logstash/conf.d/logstash.conf" "templates/logstash.conf.template" ; then
#  cube_service restart logstash
#fi

#cube_service enable logstash
#cube_service start logstash

#if cube_set_file_contents "/etc/rsyslog.conf" "templates/rsyslog.conf.template" ; then
#  cube_service restart rsyslog
#fi

#if cube_set_file_contents "/etc/rsyslog.d/01-server.conf" "templates/rsyslog_server.conf" ; then
#  cube_service restart rsyslog
#fi

#if cube_set_file_contents "/etc/rsyslog.d/60-logstash.conf" "templates/rsyslog_logstash.conf.template" ; then
#  cube_service restart rsyslog
#fi

# https://www.elastic.co/guide/en/kibana/current/setup.html
cube_read_stdin cubevar_app_str <<'HEREDOC'
[kibana-5.x]
name=Kibana repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
HEREDOC

cube_set_file_contents_string "/etc/yum.repos.d/kibana.repo" "${cubevar_app_str}"

cube_package install kibana
