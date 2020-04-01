#!/bin/bash

echo "#################################"
echo "   Running OOB_Switch_Config.sh"
echo "#################################"
sudo su

# cosmetic fix for dpkg-reconfigure: unable to re-open stdin: No file or directory during vagrant up
export DEBIAN_FRONTEND=noninteractive

# Config for OOB Switch
cat <<EOT > /etc/network/interfaces
auto lo
iface lo inet loopback

auto vagrant
iface vagrant inet dhcp

#auto eth0
#iface eth0 inet dhcp

source /etc/network/interfaces.d/*
EOT

#/usr/share/doc/ifupdown2/examples/generate_interfaces.py -b | grep -v "#" >> /etc/network/interfaces.d/bridge

#sed -i 's/vagrant//g' /etc/network/interfaces.d/bridge
#sed -i 's/eth0//g' /etc/network/interfaces.d/bridge
#sed -i 's/iface bridge-untagged/iface bridge-untagged inet dhcp/' /etc/network/interfaces.d/bridge

cp /home/vagrant/bridge-untagged /etc/network/interfaces.d/bridge-untagged

## air agent install
echo "Install AIR agent"
echo 'deb http://deb.debian.org/debian/ jessie main' | sudo tee -a /etc/apt/sources.list
apt-get update
apt-get install -yq git build-essential libssl-dev libffi-dev python3-dev python3-setuptools
# As of February 2020, pip3 v20.x.x is having issues installing our dependencies,
#  so use v19.3.1 for now
sudo easy_install3 pip==19.3.1 2>/dev/null

git clone -b python3.4 https://gitlab.com/cumulus-consulting/air/air-agent.git >/dev/null 2>&1 #creates red output in vagrant
cd air-agent
sudo ./install.sh

echo "#################################"
echo "   Finished "
echo "#################################"

