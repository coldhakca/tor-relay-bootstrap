#!/bin/bash

set -e

# check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# update software
echo "== Updating software"
apt update
apt upgrade -y

apt install -y lsb-release apt-transport-https

# add official Tor repository
if ! grep -q "https://deb.torproject.org/torproject.org" /etc/apt/sources.list; then
    echo "== Adding the official Tor repository"
    echo "deb https://deb.torproject.org/torproject.org `lsb_release -cs` main" >> /etc/apt/sources.list
    gpg --keyserver keys.gnupg.net --recv A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
    gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
    apt update
fi

# install tor and related packages
echo "== Installing Tor and related packages"
apt install -y deb.torproject.org-keyring tor tor-arm tor-geoipdb
service tor stop

# configure tor
cp $PWD/etc/tor/torrc /etc/tor/torrc

# configure firewall rules
echo "== Configuring firewall rules"
apt install -y debconf-utils
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
apt install -y iptables iptables-persistent
cp $PWD/etc/iptables/rules.v4 /etc/iptables/rules.v4
cp $PWD/etc/iptables/rules.v6 /etc/iptables/rules.v6
chmod 600 /etc/iptables/rules.v4
chmod 600 /etc/iptables/rules.v6
iptables-restore < /etc/iptables/rules.v4
ip6tables-restore < /etc/iptables/rules.v6

apt install -y fail2ban

# configure automatic updates
echo "== Configuring unattended upgrades"
apt install -y unattended-upgrades apt-listchanges
cp $PWD/etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades
service unattended-upgrades restart

# install apparmor
apt install -y apparmor apparmor-profiles apparmor-utils
sed -i.bak 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 apparmor=1 security=apparmor"/' /etc/default/grub
update-grub

# install ntp (tlsdate is no longer available in Debian stable)
apt install -y ntp

# install monit
apt install -y monit
cp $PWD/etc/monit/conf.d/tor-relay.conf /etc/monit/conf.d/tor-relay.conf
service monit restart

# configure sshd
ORIG_USER=$(logname)
if [ -n "$ORIG_USER" ]; then
	echo "== Configuring sshd"
	# only allow the current user to SSH in
	echo "AllowUsers $ORIG_USER" >> /etc/ssh/sshd_config
	echo "  - SSH login restricted to user: $ORIG_USER"
	if grep -q "Accepted publickey for $ORIG_USER" /var/log/auth.log; then
		# user has logged in with SSH keys so we can disable password authentication
		sed -i '/^#\?PasswordAuthentication/c\PasswordAuthentication no' /etc/ssh/sshd_config
		echo "  - SSH password authentication disabled"
		if [ $ORIG_USER == "root" ]; then
			# user logged in as root directly (rather than using su/sudo) so make sure root login is enabled
			sed -i '/^#\?PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config
		fi
	else
		# user logged in with a password rather than keys
		echo "  - You do not appear to be using SSH key authentication.  You should set this up manually now."
	fi
	service ssh reload
else
	echo "== Could not configure sshd automatically.  You will need to do this manually."
fi

# final instructions
echo ""
echo "== Try SSHing into this server again in a new window, to confirm the firewall isn't broken"
echo ""
echo "== Edit /etc/tor/torrc"
echo "  - Set Address, Nickname, Contact Info, and MyFamily for your Tor relay"
echo "  - Optional: limit the amount of data transferred by your Tor relay (to avoid additional hosting costs)"
echo "    - Uncomment the lines beginning with '#AccountingMax' and '#AccountingStart'"
echo ""
echo "== Consider having /etc/apt/sources.list update over HTTPS and/or HTTPS+Tor"
echo "   see https://guardianproject.info/2014/10/16/reducing-metadata-leakage-from-software-updates/"
echo "   for more details"
echo ""
echo "== REBOOT THIS SERVER"
