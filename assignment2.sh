#!/bin/bash

# Assignment 2 - System Modification

# Configuration Variables
targetIP="192.168.16.21"
targetHostname="server1"
netplanConfigFile="/etc/netplan/00-installer-config.yaml"

# The Account List:
USERS=(
    "aubrey"
    "captain"
    "snibbles"
    "brownie"
    "scooter"
    "sandy"
    "perrier"
    "cindy"
    "tiger"
    "yoda"
)

# Special user with sudo access and extra SSH key:
specialUser="dennis"
specialUserSSHKey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

# --- Main Script ---
echo "---------------------------------------------------------"
echo "[INFO] Starting Assignment 2 System Modification Script..."
echo "---------------------------------------------------------"

# --------------------------------------------------------------------------
# SECTION 1: Network Configuration
echo ""
echo "---------------------------------------------------------"
echo "[INFO] Configuring network interface for ${targetIP}..."
echo "---------------------------------------------------------"

# Look for the non-management network interface.
# Assuming that eth0 is used for management. If your setup differs, this might need adjustment.
networkInterface=$(ip -o -4 addr show | grep 'inet 192\.168\.16\.' | awk '{print $2}' | cut -d'@' -f1 | head -n 1)

if [ -z "$networkInterface" ]; then
    echo "[ERROR] Could not identify the non-mgmt network interface. Script will not proceed."
# This will exit the script if we can't find the network interface.
    exit 1 
else
    echo "[INFO] Identified network interface for 192.168.16.x network: ${networkInterface}"
fi

# Check if the desired IP is already configured in netplan for this interface
# This check is a bit simplistic for YAML, but aims to be idempotent.
# It checks if the interface name and the target IP/24 are both present on expected lines.
if sudo grep -qE "^\s*${networkInterface}:" "$netplanConfigFile" && \
   sudo grep -qE "^\s*addresses:\s*\[\"${targetIP}\/24\"\]" "$netplanConfigFile"; then
    echo "[SUCCESS] Netplan already configured with ${targetIP} for ${networkInterface}."
else
    echo "[INFO] Netplan configuration needs update for ${networkInterface}."
    echo "[INFO] Backing up original Netplan file to ${netplanConfigFile}.bak"
    sudo cp "$netplanConfigFile" "${netplanConfigFile}.bak"
    echo "[INFO] Generating new Netplan configuration for ${networkInterface}..."
    sudo bash -c "cat > ${netplanConfigFile} <<EOF
network:
  ethernets:
    ${networkInterface}:
      dhcp4: no
      addresses: [\"${targetIP}/24\"]
      routes:
        - to: default
          via: 192.168.16.2
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
    eth1:
      dhcp4: yes
  version: 2
  renderer: networkd
EOF"
    echo "[SUCCESS] New Netplan configuration written to ${netplanConfigFile}."

    echo "[INFO] Applying Netplan configuration..."
    if sudo netplan apply; then
        echo "[SUCCESS] Netplan configuration applied successfully."
    else
        echo "[ERROR] Failed to apply Netplan configuration. Check ${netplanConfigFile} for errors."
        echo "[ERROR] It's possible you may need to recreate server1 if network state is bad."
    fi
fi

echo ""
echo "---------------------------------------------------------"
echo "[INFO] Updating /etc/hosts for ${targetHostname} (${targetIP})..."
echo "---------------------------------------------------------"

hostsFile="/etc/hosts"

# Check if the correct entry exists
if grep -qE "^${targetIP}\s+${targetHostname}(\s|$)" "$hostsFile"; then
    echo "[SUCCESS] ${targetHostname} is already correctly configured in ${hostsFile}."
else
# Remove any old entries for server1 that don't match the new IP
# This greps for lines containing 'server1' but NOT the new IP.
    oldEntriesCount=$(grep -E "\s+${targetHostname}(\s|$)" "$hostsFile" | grep -vE "^${targetIP}\s+" | wc -l)
    if [ "$oldEntriesCount" -gt 0 ]; then
        echo "[INFO] Removing old entries for ${targetHostname} in ${hostsFile}..."
# Delete lines containing the hostname server1, but not if they contain the new IP.
        sudo sed -i "/\(\s\|^\)${targetHostname}\(\s\|$\)/ { /^\s*${targetIP}\s\+${targetHostname}/!d }" "$hostsFile"
        echo "[INFO] Old entries removed."
    fi

# Add the new, correct entry
    echo "[INFO] Adding ${targetIP} ${targetHostname} to ${hostsFile}..."
    echo "${targetIP} ${targetHostname}" | sudo tee -a "$hostsFile" > /dev/null
    echo "[SUCCESS] ${targetIP} ${targetHostname} added to ${hostsFile}."
fi

# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# SECTION 2: Software Installation
echo ""
echo "---------------------------------------------------------"
echo "[INFO] Installing and configuring required software..."
echo "---------------------------------------------------------"

# Function to install and enable a package idempotently
install_and_enable_package() {
    local packageName="$1"
    echo "[INFO] Checking ${packageName}..."

# Check if package is installed
    if dpkg -s "$packageName" &> /dev/null; then
        echo "[SUCCESS] ${packageName} is already installed."
    else
        echo "[INFO] Installing ${packageName}..."
        if sudo apt update && sudo apt install -y "$packageName"; then
            echo "[SUCCESS] ${packageName} installed successfully."
        else
            echo "[ERROR] Failed to install ${packageName}. Please check APT sources."
# Indicate failure
            return 1
        fi
    fi

    # Check if package is running and enabled
    if sudo systemctl is-active --quiet "$packageName" && sudo systemctl is-enabled --quiet "$packageName"; then
        echo "[SUCCESS] ${packageName} is already running and enabled."
    else
        echo "[INFO] Starting and enabling ${packageName}..."
        if sudo systemctl start "$packageName" && sudo systemctl enable "$packageName"; then
            echo "[SUCCESS] ${packageName} started and enabled successfully."
        else
            echo "[ERROR] Failed to start or enable ${packageName}."
            return 1
        fi
    fi
# Indicate success
    return 0 
}

# Install Apache2
install_and_enable_package "apache2"
if [ $? -ne 0 ]; then echo "[WARN] Issues with Apache2 configuration. Proceeding with other tasks."; fi

# Install Squid
install_and_enable_package "squid"
if [ $? -ne 0 ]; then echo "[WARN] Issues with Squid configuration. Proceeding with other tasks."; fi

# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# SECTION 3: User Account Management
echo ""
echo "---------------------------------------------------------"
echo "[INFO] Managing user accounts and SSH keys..."
echo "---------------------------------------------------------"

# Function to create user and manage SSH keys
manage_user_and_ssh() {
# For verification: "true" or "false"
    local userName="$1"
    local heyDennis="$2"

    echo "[INFO] Processing user: ${userName}"

# 1. Create user if they don't exist
    if id -u "$userName" &> /dev/null; then
        echo "[SUCCESS] User '${userName}' already exists."
    else
        echo "[INFO] Creating user '${userName}' with home directory and bash shell..."
        if sudo useradd -m -s /bin/bash "$userName"; then
            echo "[SUCCESS] User '${userName}' created."
        else
            echo "[ERROR] Failed to create user '${userName}'. Skipping SSH setup for this user."
# Skip to next user if creation failed
            return
        fi
    fi

# Ensure that the .ssh directory exists and has correct permissions
    echo "[INFO] Ensuring SSH directory exists and has correct permissions for '${userName}'..."
    sudo -u "$userName" mkdir -p "/home/${userName}/.ssh"
    sudo chmod 700 "/home/${userName}/.ssh"
    sudo chown "$userName:$userName" "/home/${userName}/.ssh"
    echo "[SUCCESS] SSH directory configured for '${userName}'."

# 2. Generate RSA and ED25519 SSH keys
    local rsaKeyPath="/home/${userName}/.ssh/id_rsa"
    local ed25519KeyPath="/home/${userName}/.ssh/id_ed25519"
    local authorizedKeysPath="/home/${userName}/.ssh/authorized_keys"

# Generate RSA key
    if [ ! -f "$rsaKeyPath" ]; then
        echo "[INFO] Generating RSA SSH key for '${userName}'..."
        sudo -u "$userName" ssh-keygen -t rsa -f "$rsaKeyPath" -N "" > /dev/null
        echo "[SUCCESS] RSA key generated for '${userName}'."
    else
        echo "[SUCCESS] RSA key already exists for '${userName}'."
    fi

# Generate ED25519 key
    if [ ! -f "$ed25519KeyPath" ]; then
        echo "[INFO] Generating ED25519 SSH key for '${userName}'..."
        sudo -u "$userName" ssh-keygen -t ed25519 -f "$ed25519KeyPath" -N "" > /dev/null
        echo "[SUCCESS] ED25519 key generated for '${userName}'."
    else
        echo "[SUCCESS] ED25519 key already exists for '${userName}'."
    fi

# 3. Add generated public keys to authorized_keys
    echo "[INFO] Adding generated public keys to authorized_keys for '${userName}'..."
# Add RSA public key if not already present
    if ! sudo grep -qF "$(sudo cat ${rsaKeyPath}.pub)" "$authorizedKeysPath"; then
        sudo -u "$userName" bash -c "cat ${rsaKeyPath}.pub >> ${authorizedKeysPath}"
        echo "[INFO] RSA public key added to authorized_keys."
    else
        echo "[SUCCESS] RSA public key already in authorized_keys."
    fi

# Add ED25519 public key if not already present
    if ! sudo grep -qF "$(sudo cat ${ed25519KeyPath}.pub)" "$authorizedKeysPath"; then
        sudo -u "$userName" bash -c "cat ${ed25519KeyPath}.pub >> ${authorizedKeysPath}"
        echo "[INFO] ED25519 public key added to authorized_keys."
    else
        echo "[SUCCESS] ED25519 public key already in authorized_keys."
    fi

# Ensure authorized_keys has correct permissions
    sudo chmod 600 "$authorizedKeysPath"
    sudo chown "$userName:$userName" "$authorizedKeysPath"
    echo "[SUCCESS] authorized_keys permissions set for '${userName}'."

# 4. Special handling for Dennis
    if [ "$heyDennis" == "true" ]; then
        echo "[INFO] Special configuration for user '${userName}' (Dennis)..."

# Add Dennis to sudo group
        if ! groups "$userName" | grep -q "sudo"; then
            echo "[INFO] Adding '${userName}' to 'sudo' group..."
            if sudo usermod -aG sudo "$userName"; then
                echo "[SUCCESS] '${userName}' added to 'sudo' group."
            else
                echo "[ERROR] Failed to add '${userName}' to 'sudo' group."
            fi
        else
            echo "[SUCCESS] '${userName}' is already in 'sudo' group."
        fi

# Add extra public key for Dennis
        echo "[INFO] Adding external SSH key for '${userName}'..."
        if ! sudo grep -qF "${specialUserSSHKey}" "$authorizedKeysPath"; then
            echo "${specialUserSSHKey}" | sudo tee -a "$authorizedKeysPath" > /dev/null
            echo "[SUCCESS] External SSH key added for '${userName}'."
        else
            echo "[SUCCESS] External SSH key already present for '${userName}'."
        fi
    fi
    echo "[INFO] Finished processing user: ${userName}"
}

# Process Dennis first
manage_user_and_ssh "$specialUser" "true"

# Process other users
for user in "${USERS[@]}"; do
    manage_user_and_ssh "$user" "false"
done

# --------------------------------------------------------------------------

echo "---------------------------------------------------------"
echo "[SUCCESS] Assignment 2 Script completed."
echo "---------------------------------------------------------"
