#!/bin/bash
echo "#################################"
echo "  Running Extra_Server_Config.sh"
echo "#################################"

# cosmetic fix for dpkg-reconfigure: unable to re-open stdin: No file or directory during vagrant up
export DEBIAN_FRONTEND=noninteractive

useradd cumulus -m -s /bin/bash
echo "cumulus:CumulusLinux!" | chpasswd
echo "cumulus ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10_cumulus

timedatectl set-ntp false

echo "Disable DNSSEC"
sed -i 's/DNSSEC=yes/DNSSEC=no/' /etc/systemd/resolved.conf 
systemctl restart systemd-resolved.service

echo "Add Cumulus Apps Pubkey"
wget -q -O- https://apps3.cumulusnetworks.com/setup/cumulus-apps-deb.pubkey | apt-key add - 2>&1

echo "Adding Cumulus Apps Repo"
echo "deb http://apps3.cumulusnetworks.com/repos/deb bionic netq-latest" > /etc/apt/sources.list.d/netq.list

#Install LLDP & NTP
echo "Installing LLDP NTP, pip3 & NetQ"
apt-get update -qy && apt-get install lldpd ntp ntpdate python3-pip -qy
apt-get install cumulus-netq -qy
echo "configure lldp portidsubtype ifname" > /etc/lldpd.d/port_info.conf

echo "Enabling LLDP"
/lib/systemd/systemd-sysv-install enable lldpd
systemctl start lldpd.service

echo "Configuring NetQ agent"
netq config add agent server 192.168.200.250
netq config restart agent

echo "Configure etc/network/interfaces"
echo -e "auto lo" > /etc/network/interfaces
echo -e "iface lo inet loopback\n\n" >> /etc/network/interfaces
echo -e  "source /etc/network/interfaces.d/*.cfg\n" >> /etc/network/interfaces

#Add vagrant interface
echo -e "\n\nauto vagrant" > /etc/network/interfaces.d/vagrant.cfg
echo -e "iface vagrant inet dhcp\n\n" >> /etc/network/interfaces.d/vagrant.cfg

echo -e "\n\nauto eth0" > /etc/network/interfaces.d/eth0.cfg
echo -e "iface eth0 inet dhcp\n\n" >> /etc/network/interfaces.d/eth0.cfg

#Setup SSH key authentication for Ansible
echo -e "post-up mkdir -p /home/cumulus/.ssh" >> /etc/network/interfaces.d/eth0.cfg
echo -e "post-up wget -O /home/cumulus/.ssh/authorized_keys http://192.168.200.1/authorized_keys" >> /etc/network/interfaces.d/eth0.cfg
echo -e "post-up chown -R cumulus:cumulus /home/cumulus/.ssh" >> /etc/network/interfaces.d/eth0.cfg

echo "retry 1;" >> /etc/dhcp/dhclient.conf
echo "timeout 600;" >> /etc/dhcp/dhclient.conf

#Disable autoupdate
echo "Disabling Autoupdates"
echo -e "APT::Periodic::Update-Package-Lists "0";" > /etc/apt/apt.conf.d/10periodic
echo -e "APT::Periodic::Download-Upgradeable-Packages "0";" >> /etc/apt/apt.conf.d/10periodic
echo -e "APT::Periodic::AutocleanInterval "0";" >> /etc/apt/apt.conf.d/10periodic

echo "Configure NTP"
# Write NTP Configuration
cat << EOT > /etc/ntp.conf
tinker panic 0
# /etc/ntp.conf, configuration for ntpd; see ntp.conf(5) for help
driftfile /var/lib/ntp/ntp.drift
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

server 192.168.200.1 iburst

# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery
# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1
# Specify interfaces, don't listen on switch ports
interface listen eth0
EOT

echo "Enable and start NTP"
/lib/systemd/systemd-sysv-install enable ntp
systemctl start ntp.service

echo "Change console resolution"
echo 'GRUB_GFXPAYLOAD_LINUX=keep' >>/etc/default/grub
echo 'GRUB_GFXMODE=720x400'  >>/etc/default/grub
echo 'GRUB_CMDLINE_LINUX_DEFAULT="nomodeset"' >>/etc/default/grub
update-grub 2>&1 #creates red output in vagrant

echo "Install AIR agent"
git clone https://gitlab.com/cumulus-consulting/air/air-agent.git >/dev/null 2>&1 #creates red output in vagrant
cd air-agent
sudo ./install.sh 2>/dev/null

echo "Enable ipv6"
sed -i 's/net.ipv6.conf.all.disable_ipv6\ =\ 1/net.ipv6.conf.all.disable_ipv6\ =\ 0/' /etc/sysctl.conf

echo "#################################"
echo "   Finished"
echo "#################################"
