#!/bin/sh
hostname
uptime
w
df -h /
free -m
vmstat 1 5
iostat -xm 1 3 
ss --summary
