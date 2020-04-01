#!/bin/bash

echo "#################################"
echo "  Running netq_server_config.sh "
echo "#################################"

# cosmetic fix for dpkg-reconfigure: unable to re-open stdin: No file or directory during vagrant up
export DEBIAN_FRONTEND=noninteractive

useradd cumulus -m -s /bin/bash
echo "cumulus:CumulusLinux!" | chpasswd
echo "cumulus ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10_cumulus

echo "Disable DNSSEC"
sed -i 's/DNSSEC=yes/DNSSEC=no/' /etc/systemd/resolved.conf 
systemctl restart systemd-resolved.service

echo "Add Cumulus Apps Pubkey"
wget -q -O- https://apps3.cumulusnetworks.com/setup/cumulus-apps-deb.pubkey | apt-key add - 2>&1

echo "Adding Cumulus Apps Repo"
echo "deb [arch=amd64] http://apps3.cumulusnetworks.com/repos/deb bionic netq-latest" > /etc/apt/sources.list.d/cumulus-apps-deb-bionic.list

echo "Install Python for NetQ"
apt-get update 
apt-get install -qy python python2.7 python-apt

echo "Install NetQ agent and apps"
apt-get install -qy netq-agent netq-apps

echo "Install LLDP"
apt-get install -qy lldpd
echo "configure lldp portidsubtype ifname" > /etc/lldpd.d/port_info.conf

echo "Install pip3"
apt-get install -qy python3-pip

echo "Enabling LLDP"
/lib/systemd/systemd-sysv-install enable lldpd
systemctl start lldpd.service

#####Setup SSH key authentication for Ansible
mkdir -p /home/cumulus/.ssh
cat <<EOT > /etc/rc.local 
#!/bin/bash
#
wget -O /home/cumulus/.ssh/authorized_keys http://192.168.200.1/authorized_keys
chown -R cumulus:cumulus /home/cumulus/.ssh

EOT

chmod +x /etc/rc.local

echo "retry 1;" >> /etc/dhcp/dhclient.conf
echo "timeout 600;" >> /etc/dhcp/dhclient.conf
#Disable autoupdate
echo "Disabling Autoupdates"
echo -e "APT::Periodic::Update-Package-Lists "0";" > /etc/apt/apt.conf.d/10periodic
echo -e "APT::Periodic::Download-Upgradeable-Packages "0";" >> /etc/apt/apt.conf.d/10periodic
echo -e "APT::Periodic::AutocleanInterval "0";" >> /etc/apt/apt.conf.d/10periodic

echo "Applying network config"
# remap hasn't occurred yet so do not apply settings yet.
cat <<EOT > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.200.250/24]
      gateway4: 192.168.200.1
      nameservers:
        addresses: [192.168.200.1,4.2.2.2]
    eth1:
      dhcp4: yes
    vagrant:
      dhcp4: yes
EOT

#tell the service that waits for interfaces to be up to ignore eth1 and vagrant
#it makes a reboot take a long time
sed -i "s/systemd-networkd-wait-online/systemd-networkd-wait-online --ignore=eth1 --ignore=vagrant/" /lib/systemd/system/systemd-networkd-wait-online.service

echo "Remove swap from fstab"
swap_line=`cat /etc/fstab | grep swap | grep UUID`
sed -i "s/$swap_line/#$swap_line/" /etc/fstab

echo "Grow the root fs size from extra space"
growpart /dev/sda 3
resize2fs /dev/sda3 2>/dev/null

echo "Change console resolution"
echo 'GRUB_GFXPAYLOAD_LINUX=keep' >>/etc/default/grub
echo 'GRUB_GFXMODE=720x400'  >>/etc/default/grub
echo 'GRUB_CMDLINE_LINUX_DEFAULT="nomodeset"' >>/etc/default/grub
update-grub 2>&1 #creates red output in vagrant

echo "Install AIR agent"
git clone https://gitlab.com/cumulus-consulting/air/air-agent.git >/dev/null 2>&1 #creates red output in vagrant
cd air-agent
sudo ./install.sh 2>/dev/null

#disable the opta-check for config key clear
echo 'netq-cli:' >/etc/netq/netq.yml.bak
echo '  opta-check: false' >>/etc/netq/netq.yml.bak
cp /etc/netq/netq.yml.bak /etc/netq/netq.yml

echo "Enable ipv6"
sed -i 's/net.ipv6.conf.all.disable_ipv6\ =\ 1/net.ipv6.conf.all.disable_ipv6\ =\ 0/' /etc/sysctl.conf

echo "#################################"
echo "   Finished"
echo "#################################"
