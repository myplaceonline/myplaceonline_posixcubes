# myplaceonline_posixcubes

## frontend

    posixcube.sh -u root -h frontend*.myplaceonline.com -o "cubevar_app_web_servers=web*" -c core_begin -c frontend -c core_end

## web

    posixcube.sh -u root -h web*.myplaceonline.com -o "cubevar_app_web_servers=web*" -c core_begin -c web -c core_end

## primary database

    posixcube.sh -u root -h db1.myplaceonline.com -o "cubevar_app_db_servers=db*" -c core_begin -c database -c core_end

## backup database

    posixcube.sh -u root -h db2.myplaceonline.com -o "cubevar_app_db_servers=db*" -r database_backup -c core_begin -c database -c core_end

