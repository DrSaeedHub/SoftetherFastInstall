#!/bin/bash

   echo -e "\033[0;32m"
   echo "  _____          _____                     _ "
   echo " |  __ \        / ____|                   | |"
   echo " | |  | |_ __  | (___   __ _  ___  ___  __| |"
   echo " | |  | | '__|  \___ \ / _ |/ _ \/ _ \/ _ |"
   echo " | |__| | |     ____) | (_| |  __/  __/ (_| |"
   echo " |_____/|_|    |_____/ \__,_|\___|\___|\__,_|"
   echo -e "\033[0m"

export DEBIAN_FRONTEND=noninteractive

# Perform system update and upgrade
sudo apt update && sudo apt upgrade -y

# Define console colors
RED='\033[0;31m'
NC='\033[0m' # No Color

# Execute as sudo
(( EUID != 0 )) && exec sudo -- "$0" "$@"
clear

# REMOVE PREVIOUS INSTALL
# Check for SE install folder
if [ -d "/opt/vpnserver" ]; then
  rm -rf /opt/vpnserver > /dev/null 2>&1
fi

# Clean up any previous attempts
if [ -d "/tmp/softether-autoinstall" ]; then
  rm -rf /tmp/softether-autoinstall > /dev/null 2>&1
fi

# Remove old init script
if [ -f "/etc/init.d/vpnserver" ]; then
  rm /etc/init.d/vpnserver
fi

# Remove old systemd service if exists
if [ -f "/etc/systemd/system/vpnserver.service" ]; then
  rm /etc/systemd/system/vpnserver.service
fi

# Perform apt update & install necessary software
apt-get update -y
apt-get install -y wget net-tools build-essential checkinstall dos2unix libssl-dev libreadline-dev zlib1g-dev

# Create working directory
mkdir -p /tmp/softether-autoinstall
cd /tmp/softether-autoinstall

# Download SoftEther | Version 4.38 | Build 9760
printf "\nDownloading release: ${RED}4.38 RTM${NC} | Build ${RED}9760${NC}\n\n"
wget -O vpnserver.tar.gz https://www.softether-download.com/files/softether/v4.38-9760-rtm-2021.08.17-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.38-9760-rtm-2021.08.17-linux-x64-64bit.tar.gz

# Extract the archive
tar -xzf vpnserver.tar.gz
cd vpnserver

# Build SoftEther VPN Server
echo $'1\n1\n1' | make

# Move to /opt directory
cd /tmp/softether-autoinstall && mv vpnserver/ /opt

# Set proper permissions for vpnserver binaries
chmod 600 /opt/vpnserver/*
chmod 700 /opt/vpnserver/vpncmd
chmod 700 /opt/vpnserver/vpnserver

# Create a systemd service file for SoftEther VPN Server
cat <<EOF > /etc/systemd/system/vpnserver.service
[Unit]
Description=SoftEther VPN Server
After=network.target

[Service]
Type=forking
ExecStart=/opt/vpnserver/vpnserver start
ExecStop=/opt/vpnserver/vpnserver stop
ExecReload=/opt/vpnserver/vpnserver restart
WorkingDirectory=/opt/vpnserver
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to register the new service
systemctl daemon-reload

# Enable the service to start at boot
systemctl enable vpnserver

# Start the SoftEther VPN Server service
systemctl start vpnserver

# Clean up installation files
cd && rm -rf /tmp/softether-autoinstall > /dev/null 2>&1

# Check if service is running
if systemctl is-active --quiet vpnserver; then
  echo -e "${GREEN}Service vpnserver is running.${NC}"
else
  echo -e "${RED}Failed to start vpnserver service.${NC}"
fi

echo "Done."
