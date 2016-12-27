#!/bin/sh

cube_echo "Hello World"
cube_printf "Hello World"
cube_error_echo "Goodbye World"
cube_error_printf "Goodbye World"

cube_service stop atd
cube_service start atd

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
