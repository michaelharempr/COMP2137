#!/bin/bash
# Hardware Summary Report

echo "=== Hardware Summary Report ==="
echo

# OS Name with Version
echo "Operating System:"
lsb_release -d

# CPU Model Name
echo
echo "CPU Info:"
lscpu | grep "Model name"

# RAM Installed
echo
echo "Total Installed RAM:"
free -h | grep Mem | awk '{print $2}'
