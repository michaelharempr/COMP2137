#!/bin/bash
# Script to create groups, directories, users, and set permissions for the User Accounts task

# Exit immediately if any command fails
set -e

echo "Creating groups..."
for group in brews trees cars staff admins; do
  if ! getent group "$group" > /dev/null; then
    sudo groupadd "$group"
    echo "Group '$group' created."
  else
    echo "Group '$group' already exists. Skipping."
  fi
done

echo "Creating directories with correct ownership and permissions..."
for dir in brews trees cars staff admins; do
  sudo mkdir -p "/$dir"
  sudo chown root:"$dir" "/$dir"
  sudo chmod 770 "/$dir"
  echo "Directory /$dir created/updated."
done

declare -A users_group=(
  [brews]="coors stella michelob guiness"
  [trees]="oak pine cherry willow maple walnut ash apple"
  [cars]="chrysler toyota dodge chevrolet pontiac ford suzuki pontiac hyundai cadillac jaguar"
  [staff]="bill tim marilyn kevin george"
  [admins]="bob rob brian dennis"
)

echo "Creating users and assigning groups..."
for group in "${!users_group[@]}"; do
  for user in ${users_group[$group]}; do
    if ! id "$user" &>/dev/null; then
      sudo useradd -m -g "$group" "$user"
      echo "User '$user' created and added to group '$group'."
    else
      echo "User '$user' already exists. Skipping."
    fi
  done
done

echo "Adding user 'dennis' to sudo group and all other groups..."
sudo usermod -aG sudo dennis
sudo usermod -aG brews,trees,cars,staff,admins dennis

echo "Setup complete!"
echo "Please set passwords for the users as needed using 'sudo passwd username'."
