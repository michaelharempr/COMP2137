#!/bin/bash
# Script to report storage usage and mounted filesystems

echo "=== Mounted Local Filesystems ==="
df -hT | grep -E '^/dev'

echo -e "\n=== Mounted Network Filesystems ==="
mount | grep -E 'nfs|cifs|smb'

echo -e "\n=== Free Space in Home Directory Filesystem ==="
df -h ~

echo -e "\n=== Space and File Count in ~/COMP2137 ==="
du -sh ~/COMP2137
echo -n "Files: "
find ~/COMP2137 -type f | wc -l
