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
apt-get install -y libpq-dev
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

if [ -d "/tmp/softether-autoinstall" ]; then
  rm -rf /tmp/softether-autoinstall > /dev/null 2>&1
fi

# Check for init script
if
  [ -f "/etc/init.d/vpnserver" ]; then rm /etc/init.d/vpnserver;
fi

# Remove vpnserver from systemd
update-rc.d vpnserver remove > /dev/null 2>&1

# Create working directory
mkdir -p /tmp/softether-autoinstall
cd /tmp/softether-autoinstall

# Perform apt update & install necessary software
apt-get update -y && apt-get install wget -y && apt-get install net-tools -y

# Install build-essential and checkinstall
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' build-essential|grep "install ok installed")
echo  "Checking for build-essential: $PKG_OK"
if [ "" == "$PKG_OK" ]; then
  echo "build-essential not installed. Installing now."
  sudo apt install -y build-essential
fi

PKG_OK=$(dpkg-query -W --showformat='${Status}\n' checkinstall|grep "install ok installed")
echo "Checking for checkinstall: $PKG_OK"
if [ "" == "$PKG_OK" ]; then
  echo "checkinstall not installed. Installing now."
  sudo apt install -y checkinstall
fi

PKG_OK=$(dpkg-query -W --showformat='${Status}\n' build-essential|grep "install ok installed")
echo  "Checking for build-essential: $PKG_OK"
if [ "" == "$PKG_OK" ]; then
  echo "build-essential is still not installed. Possible problem with apt? Exiting."
  exit 1
fi

# Download SoftEther | Version 4.38 | Build 9760
printf "\nDownloading release: ${RED}4.38 RTM${NC} | Build ${RED}9760${NC}\n\n"
wget -O vpnserver.tar.gz https://www.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz
tar -xzf vpnserver.tar.gz
cd vpnserver
echo $'1\n1\n1' | make &&
cd /tmp/softether-autoinstall && mv vpnserver/ /opt
chmod 600 /opt/vpnserver/* && chmod 700 /opt/vpnserver/vpncmd && chmod 700 /opt/vpnserver/vpnserver
cd /tmp/softether-autoinstall

# Set SoftEther service
wget -O vpnserver-init https://raw.githubusercontent.com/icoexist/softether-autoinstall/master/vpnserver-init > /dev/null 2>&1
mv vpnserver-init /etc/init.d/vpnserver
chmod 755 /etc/init.d/vpnserver
printf "\nSystem daemon created. Registering changes...\n\n"
update-rc.d vpnserver defaults > /dev/null 2>&1
printf "\nSoftEther VPN Server should now start as a system service from now on.\n\n"
systemctl start vpnserver
printf "\nCleaning up...\n\n"
cd && rm -rf /tmp/softether-autoinstall > /dev/null 2>&1
systemctl is-active --quiet vpnserver && echo "Service vpnserver is running."
echo "Done."
