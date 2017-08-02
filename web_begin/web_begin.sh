#!/bin/sh

# Ruby uses a lot of memory, so first stop weighty processes. Wrap in a sub-shell to eat any exceptions (e.g. if
# first setting up the box and the service doesn't exist)
(cube_service stop nginx) 2>/dev/null
(cube_service stop myplaceonline-delayedjobs) 2>/dev/null
