#!/bin/sh

pushd "$(dirname "$0")/../"

POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED=

export POSIXCUBE_COLORS=true

posixcube.sh -u root -h ${cubevar_app_primary_host_web_public} "cd /var/www/html/myplaceonline/; "RAILS_ENV=${cubevar_app_rails_environment}" "FTS_TARGET=${cubevar_app_full_text_search_target}" "BUNDLE_GEMFILE=${cubevar_app_rails_gemfile}" "SECRET_KEY_BASE=${cubevar_app_passwords_devise_secret}" "ROOT_EMAIL=${cubevar_app_root_email}" "ROOT_PASSWORD=${cubevar_app_passwords_rails_root}" "SMTP_HOST=${cubevar_app_outbound_smtp}" "SMTP_USER=${cubevar_app_passwords_smtp_user}" "SMTP_PASSWORD=${cubevar_app_passwords_smtp_password}" "MAIL_FROM=${cubevar_app_mail_from}" "PERMDIR=${cubevar_app_nfs_client_mount}" "TWILIO_NUMBER=${cubevar_app_passwords_twilio_number}" "TWILIO_ACCOUNT=${cubevar_app_passwords_twilio_account}" "TWILIO_AUTH=${cubevar_app_passwords_twilio_auth}" "MIGRATING=true" "MINCACHE=true" bin/rails console"

popd

