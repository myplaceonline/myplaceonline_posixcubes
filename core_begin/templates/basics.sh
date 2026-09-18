#!/bin/sh
hostname
echo "===================="
w
echo "===================="
df -h /
echo "===================="
free -m
echo "===================="
vmstat 1 5
echo "===================="
iostat -xm 1 3 
echo "===================="
ss --summary
echo "===================="
