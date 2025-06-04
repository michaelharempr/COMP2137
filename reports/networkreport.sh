#!/bin/bash
# Network Configuration Summary Report

echo "=== Network Configuration Summary Report ==="
echo

# Interface names and NIC model descriptions
echo "Interfaces and NIC Descriptions:"
lshw -class network | grep -E "logical name|product"

# IP addresses per interface
echo
echo "IP Addresses:"
ip -brief address show | awk '{print $1, $3}'

# Default gateway IP
echo
echo "Default Gateway:"
ip route | grep default | awk '{print $3}'
