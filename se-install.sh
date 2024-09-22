#!/bin/bash

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

export DEBIAN_FRONTEND=noninteractive

# Console colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Perform system update and upgrade
echo -e "${GREEN}Updating system packages...${NC}"
apt update && apt upgrade -y

# REMOVE PREVIOUS INSTALLATION
echo -e "${GREEN}Removing previous installations...${NC}"
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

# Install dependencies
echo -e "${GREEN}Installing required dependencies...${NC}"
apt-get install -y wget net-tools build-essential checkinstall dos2unix libssl-dev libreadline-dev zlib1g-dev

# Create working directory
mkdir -p /tmp/softether-autoinstall
cd /tmp/softether-autoinstall

# Download SoftEther VPN Server
SOFTETHER_VERSION="4.43"
SOFTETHER_BUILD="9799"
DOWNLOAD_URL="https://www.softether-download.com/files/softether/v4.43-9799-beta-2023.08.31-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz"

echo -e "\nDownloading release: ${RED}${SOFTETHER_VERSION} RTM${NC} | Build ${RED}${SOFTETHER_BUILD}${NC}\n"
wget -O vpnserver.tar.gz "$DOWNLOAD_URL"

# Extract the archive
echo -e "${GREEN}Extracting the SoftEther archive...${NC}"
tar -xzf vpnserver.tar.gz
cd vpnserver

# Build SoftEther VPN Server
echo -e "${GREEN}Building SoftEther VPN Server...${NC}"
echo $'1\n1\n1' | make

# Move binaries to /opt directory
echo -e "${GREEN}Installing VPN Server to /opt/vpnserver...${NC}"
mv /tmp/softether-autoinstall/vpnserver /opt

# Set proper permissions for vpnserver binaries
chmod 600 /opt/vpnserver/*
chmod 700 /opt/vpnserver/vpncmd
chmod 700 /opt/vpnserver/vpnserver

# Create systemd service file for SoftEther VPN Server
echo -e "${GREEN}Setting up systemd service...${NC}"
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

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable vpnserver
systemctl start vpnserver

# Clean up installation files
echo -e "${GREEN}Cleaning up installation files...${NC}"
cd && rm -rf /tmp/softether-autoinstall > /dev/null 2>&1

# Check if service is running
if systemctl is-active --quiet vpnserver; then
  echo -e "${GREEN}Service vpnserver is running.${NC}"
else
  echo -e "${RED}Failed to start vpnserver service.${NC}"
fi

echo -e "${GREEN}SoftEther VPN Server installation completed successfully!${NC}"
echo "Done."
