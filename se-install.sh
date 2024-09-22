#!/bin/bash

# SoftEther VPN Server installation script for Ubuntu 24.04 (64-bit Intel/AMD)
# ASCII Art Header
echo -e "\033[0;32m"
echo "  _____          _____                     _ "
echo " |  __ \        / ____|                   | |"
echo " | |  | |_ __  | (___   __ _  ___  ___  __| |"
echo " | |  | | '__|  \___ \ / _ |/ _ \/ _ \/ _ |"
echo " | |__| | |     ____) | (_| |  __/  __/ (_| |"
echo " |_____/|_|    |_____/ \__,_|\___|\___|\__,_|"
echo -e "\033[0m"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo -e "\033[0;31mThis script must be run as root. Please run again with 'sudo'.\033[0m"
  exit 1
fi


set -e

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please try again with sudo."
   exit 1
fi

# Variables
SOFTETHER_URL="https://www.softether-download.com/files/softether/v4.43-9799-beta-2023.08.31-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz"
INSTALL_DIR="/usr/local/vpnserver"

# Update system packages
echo "Updating system packages..."
apt update && apt upgrade -y

# Install dependencies
echo "Installing required dependencies..."
apt install -y build-essential libreadline-dev libssl-dev libncurses5-dev zlib1g-dev make

# Download the latest SoftEther VPN Server
echo "Downloading SoftEther VPN Server..."
curl -L $SOFTETHER_URL -o softether-vpnserver.tar.gz

# Extract the downloaded archive
echo "Extracting SoftEther VPN Server..."
tar -xzvf softether-vpnserver.tar.gz

# Move to the VPN server directory
cd vpnserver

# Build SoftEther VPN Server
echo "Building SoftEther VPN Server..."
make

# Move VPN Server files to the install directory
echo "Installing SoftEther VPN Server to $INSTALL_DIR..."
mkdir -p $INSTALL_DIR
mv vpnserver vpncmd hamcore.se2 $INSTALL_DIR

# Set appropriate permissions
echo "Setting permissions..."
chmod 600 $INSTALL_DIR/*
chmod 700 $INSTALL_DIR/vpnserver
chmod 700 $INSTALL_DIR/vpncmd

# Create systemd service file
echo "Creating systemd service file..."
cat > /etc/systemd/system/vpnserver.service <<EOF
[Unit]
Description=SoftEther VPN Server
After=network.target

[Service]
Type=forking
ExecStart=$INSTALL_DIR/vpnserver start
ExecStop=$INSTALL_DIR/vpnserver stop
ExecReload=$INSTALL_DIR/vpnserver restart
WorkingDirectory=$INSTALL_DIR
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
echo "Enabling and starting VPN Server service..."
systemctl daemon-reload
systemctl enable vpnserver
systemctl start vpnserver

# Clean up installation files
cd ..
rm -rf vpnserver softether-vpnserver.tar.gz

# Show VPN server status
systemctl status vpnserver

echo "SoftEther VPN Server installation completed successfully!"
echo "You can now configure the server using $INSTALL_DIR/vpncmd."

