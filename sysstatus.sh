#!/bin/bash
# Script to display CPU load, memory usage, and disk space

echo "CPU Load:"
uptime

echo -e "\nFree Memory:"
free -h

echo -e "\nDisk Space:"
df -h
