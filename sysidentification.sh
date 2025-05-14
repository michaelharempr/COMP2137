#!/bin/bash

# a script to display the current hostname, IP address, and gateway IP

# find and display the hostname
echo -n "Hostname: "
hostname

# find and display the ip address (IPV4 for the primary interface, which 
echo -n "My IP: "
ip r s default | awk '{print $9}'
# find and display the gateway ip (AKA default ip route
# command: ip route show default | awk '{print $3}'
echo -n "Default router: "
ip r s default | awk '{print $3}'
