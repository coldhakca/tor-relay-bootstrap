tor-relay-bootstrap
===================

This is a script to bootstrap a Debian server to be a set-and-forget Tor relay. It should work on any modern Debian or Ubuntu version. Pull requests are welcome.

tor-relay-bootstrap does this:

* Upgrades all software on the system
* Installs apt-transport-tor
* Configures apt sources to use Debian's onion service mirrors (Debian only)
* Adds the deb.torproject.org (onion) repository to apt, so Tor updates will come directly from the Tor Project
* Installs and configures Tor to be a relay (but still requires you to manually edit torrc to set Nickname, ContactInfo, etc. for this relay)
* Allows you to configure multiple Tor instances for high bandwidth connections
* Configures sane default firewall rules
* Configures automatic updates
* Installs ntp to ensure time is synced
* Installs monit and activate config to auto-restart all services
* Helps harden the ssh server
* Gives instructions on what the sysadmin needs to manually do at the end

To use it, set up a Debian server, SSH into it, and:

```sh
sudo apt install -y git
git clone https://github.com/Sixdsn/tor-relay-bootstrap.git
sudo ./bootstrap.sh
```
