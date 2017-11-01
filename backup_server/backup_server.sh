#!/bin/sh

cube_ensure_user backup_user
cube_user_ensure_authorized_public_key "${cubevar_app_backup_user_ssh_key_public}" backup_user
