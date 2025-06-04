#!/bin/bash
# Storage Summary Report

echo "=== Storage Summary Report ==="
echo

# Disk models and sizes
echo "Installed Disk Models and Sizes:"
lsblk -d -o NAME,MODEL,SIZE

# ext4 filesystems size and usage
echo
echo "ext4 Filesystems Usage:"
df -Th | grep ext4
