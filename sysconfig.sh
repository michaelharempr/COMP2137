#!/bin/bash
# System configuration script: hostname, timezone, and NTP sync

# Set persistent hostname
sudo hostnamectl set-hostname pc200610214

# Set timezone to Toronto
sudo timedatectl set-timezone America/Toronto

# Sync time with NTP
sudo ntpdate time.nist.gov

# Display final status
echo "Updated system configuration:"
hostnamectl
timedatectl
