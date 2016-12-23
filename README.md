# myplaceonline_posixcubes

Assumes known SSH hosts of all web servers
    
## frontend

    posixcube.sh -u root -h frontend*.myplaceonline.com -o "cubevar_app_web_servers=web*" -c core_begin -c frontend -c core_end

## web

    posixcube.sh -u root -h web*.myplaceonline.com -o "cubevar_app_web_servers=web*" -c core_begin -c web -c core_end

