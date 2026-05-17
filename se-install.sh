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

INSTALL_DIR="/opt/vpnserver"
WORK_DIR="/tmp/softether-autoinstall"
SYSTEMD_SERVICE="/etc/systemd/system/vpnserver.service"
INIT_SCRIPT="/etc/init.d/vpnserver"
SERVICE_NAME="vpnserver"

usage() {
  echo "Usage: $0 [--uninstall]"
}

uninstall_softether() {
  local show_success="${1:-true}"

  echo -e "${GREEN}Stopping SoftEther VPN Server service...${NC}"
  if command -v systemctl > /dev/null 2>&1; then
    systemctl stop "$SERVICE_NAME" > /dev/null 2>&1 || true
    systemctl disable "$SERVICE_NAME" > /dev/null 2>&1 || true
  elif [ -x "$INIT_SCRIPT" ]; then
    "$INIT_SCRIPT" stop > /dev/null 2>&1 || true
  fi

  if [ -x "$INSTALL_DIR/vpnserver" ]; then
    "$INSTALL_DIR/vpnserver" stop > /dev/null 2>&1 || true
  fi

  echo -e "${GREEN}Removing SoftEther VPN Server files...${NC}"
  rm -rf "$INSTALL_DIR" > /dev/null 2>&1
  rm -rf "$WORK_DIR" > /dev/null 2>&1
  rm -f "$INIT_SCRIPT" > /dev/null 2>&1
  rm -f "$SYSTEMD_SERVICE" > /dev/null 2>&1

  if command -v systemctl > /dev/null 2>&1; then
    systemctl daemon-reload > /dev/null 2>&1 || true
    systemctl reset-failed "$SERVICE_NAME" > /dev/null 2>&1 || true
  fi

  if [ "$show_success" = "true" ]; then
    echo -e "${GREEN}SoftEther VPN Server uninstall completed successfully!${NC}"
  fi
}

case "$1" in
  "")
    ;;
  --uninstall)
    uninstall_softether
    echo "Done."
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo -e "${RED}Unknown argument: $1${NC}"
    usage
    exit 1
    ;;
esac

# Perform system update and upgrade
echo -e "${GREEN}Updating system packages...${NC}"
apt update && apt upgrade -y

# REMOVE PREVIOUS INSTALLATION
echo -e "${GREEN}Removing previous installations...${NC}"
uninstall_softether false

# Install dependencies
echo -e "${GREEN}Installing required dependencies...${NC}"
apt-get install -y wget net-tools build-essential checkinstall dos2unix libssl-dev libreadline-dev zlib1g-dev

# Create working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

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
mv "$WORK_DIR/vpnserver" /opt

# Set proper permissions for vpnserver binaries
chmod 600 "$INSTALL_DIR"/*
chmod 700 "$INSTALL_DIR/vpncmd"
chmod 700 "$INSTALL_DIR/vpnserver"

# Create systemd service file for SoftEther VPN Server
echo -e "${GREEN}Setting up systemd service...${NC}"
cat <<EOF > "$SYSTEMD_SERVICE"
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
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Clean up installation files
echo -e "${GREEN}Cleaning up installation files...${NC}"
cd && rm -rf "$WORK_DIR" > /dev/null 2>&1

# Check if service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo -e "${GREEN}Service $SERVICE_NAME is running.${NC}"
else
  echo -e "${RED}Failed to start $SERVICE_NAME service.${NC}"
fi

echo -e "${GREEN}SoftEther VPN Server installation completed successfully!${NC}"
echo "Done."
