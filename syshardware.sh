#!/bin/bash
# Script to identify system hardware information

echo "=== Network Interfaces ==="
ip link show | grep -E '^[0-9]:' | awk -F: '{print $2}' | xargs

echo -e "\n=== CPU Info ==="
lscpu | grep -E 'Model name|CPU\(s\)|MHz'

echo -e "\n=== Memory Info ==="
sudo dmidecode --type memory | grep -E 'Size:|Manufacturer:' | grep -v "No Module"

echo -e "\n=== Disk Drives ==="
lsblk -o NAME,SIZE,MODEL

echo -e "\n=== Video Card ==="
lspci | grep -i vga
