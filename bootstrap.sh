#!/bin/bash
#####################################################################
#
# bootstrap.sh
# -------------------
# Configures Debian / Ubuntu to be a set-and-forget Tor relay.
#
#####################################################################

PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DISTRO=$(lsb_release -si)
instances=()

# check for root
function check_root () {
	if [[ $EUID -ne 0 ]]; then
		echo "This script must be run as root (use su / sudo)" 1>&2
    		exit 1
	fi
}

# suggest user account
function suggest_user () {
	ORIG_USER=$(logname)
	if [ "$ORIG_USER" == "root" ]; then
		echo "It appears that you have logged into this machine as root. If you would like to disable remote root access, create a user account and use su / sudo to run bootstrap.sh."
		echo "Would you like to continue and allow remote root access? [y/n]"
		read useroot
		if [ "$useroot" != "y" ]; then
			exit 1
		fi
	fi
}

# update software
function update_software() {
	echo "== Updating software"
	apt-get update
	apt-get dist-upgrade -y
	apt-get install -y lsb-release apt-transport-tor
}

# add official Tor repository and Debian onion service mirrors
function add_sources() {
	if ! grep -q "tor+http://sdscoq7snqtznauu.onion/torproject.org" /etc/apt/sources.list; then
		if [ "$DISTRO" == "Debian"]; then
			echo "== Removing previous sources"
			rm /etc/apt/sources.list
			echo "== Adding the official Tor repository"
			echo "deb tor+http://sdscoq7snqtznauu.onion/torproject.org `lsb_release -cs` main" >> /etc/apt/sources.list
			echo "== Switching to Debian's onion service mirrors"
			echo "deb tor+http://vwakviie2ienjx6t.onion/debian `lsb_release -cs` main" >> /etc/apt/sources.list
			echo "deb tor+http://vwakviie2ienjx6t.onion/debian `lsb_release -cs`-updates main">> /etc/apt/sources.list
			gpg --keyserver keys.gnupg.net --recv A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
			gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
		elif ["$DISTRO"=="Ubuntu"]; then
			echo "==Adding the official Tor repository"
			echo "deb tor+http://sdscoq7snqtznauu.onion/torproject.org `lsb_release -cs` main" >> /etc/apt/sources.list
			gpg --keyserver keys.gnupg.net --recv A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
			gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
		else
			echo "You do not appear to be running Debian or Ubuntu"
			exit 1
		fi
	fi
}

# Update sources
function update_sources() {
	# wait for tor
	sleep 5
	apt-get update
}

# install tor and related packages
function install_tor() {
	echo "== Installing Tor and related packages"
	apt-get install -y deb.torproject.org-keyring tor tor-arm tor-geoipdb
	service tor stop
}

# create tor instance
function create_instance(instance) {
	tor-instance-create $instance
}

# create one or more tor instances
function create_instances() {
	instance=0
	more=1
	while [ $more == 1 ]; do
		create_instance($instance)
		instances+=($instance)
		echo "Would you like to create another instance? [N/y/?]"
		read response
		if [ $response != "y" ]; do
			more=0
		else
			instance=$((instance+1))
		done
		fi
	done
}

# create firewall rule for a single instance
function instance_rules(instance) {
	# insert rules after ## allow Tor ORPort, DirPort
	orport=$((instance+9001))
	dirport=$((instance+9030))
	sed -i "/## allow Tor ORPort, DirPort/ \
	-A INPUT -p tcp --dport $orport -j ACCEPT \
	-A INPUT -p tcp --dport $dirport -j ACCEPT" /etc/iptables/rule.v4
}

# configure firewall rules
function configure_firewall() {
	echo "== Configuring firewall rules"
	apt-get install -y debconf-utils
	echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
	echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
	apt-get install -y iptables iptables-persistent
	cp $PWD/etc/iptables/rules.v4 /etc/iptables/rules.v4
	cp $PWD/etc/iptables/rules.v6 /etc/iptables/rules.v6
	# for each instance call instance_rules
	chmod 600 /etc/iptables/rules.v4
	chmod 600 /etc/iptables/rules.v6
	iptables-restore < /etc/iptables/rules.v4
	ip6tables-restore < /etc/iptables/rules.v6
}

function install_f2b() {
	apt-get install -y fail2ban
}

# configure automatic updates
function auto_update() {
	echo "== Configuring unattended upgrades"
	apt-get install -y unattended-upgrades apt-listchanges
	cp $PWD/etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades
	service unattended-upgrades restart
}

# install apparmor
function install_aa() {
	apt-get install -y apparmor apparmor-profiles apparmor-utils
	sed -i.bak 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 apparmor=1 security=apparmor"/' /etc/default/grub
	update-grub
}

# install tlsdate
function install_td() {
	apt-get install -y tlsdate
}

# install monit
function install_mt() {
	apt-get install -y monit
	cp $PWD/etc/monit/conf.d/tor-relay.conf /etc/monit/conf.d/tor-relay.conf
	service monit restart
}

# configure sshd
function configure_ssh() {
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
}

# final instructions
function print_final() {
	echo ""
	echo "== Try SSHing into this server again in a new window, to confirm the firewall isn't broken"
	echo ""
	echo "== Edit /etc/tor/torrc"
	echo "  - Set Address, Nickname, Contact Info, and MyFamily for your Tor relay"
	echo "  - Optional: include a Bitcoin address in the 'ContactInfo' line"
	echo "    - This will enable you to receive donations from OnionTip.com"
	echo "  - Optional: limit the amount of data transferred by your Tor relay (to avoid additional hosting costs)"
	echo "    - Uncomment the lines beginning with '#AccountingMax' and '#AccountingStart'"
	echo ""
	echo "== If you are running Ubuntu (We do this automatically in Debian), consider having /etc/apt/sources.list update over HTTPS and/or HTTPS+Tor"
	echo "   see https://guardianproject.info/2014/10/16/reducing-metadata-leakage-from-software-updates/"
	echo "   for more details"
	echo ""
	echo "== REBOOT THIS SERVER"
}

check_root
suggest_user 
update_software
add_sources
update_sources
install_tor
configure_tor
configure_firewall
install_f2b
auto_update
install_aa
install_td
install_mt
configure_ssh
print_final
