tor-relay-bootstrap
===================

This is a script to bootstrap a Debian server to be a set-and-forget Tor relay. I've tested it in Jessie, but it should work on any modern Debian or Ubuntu version. Pull requests are welcome.

tor-relay-bootstrap does this:

* Upgrades all the software on the system
* Adds the deb.torproject.org repository to apt, so Tor updates will come directly from the Tor Project
* Installs and configures Tor to be a relay (but still requires you to manually edit torrc to set Nickname, ContactInfo, etc. for this relay)
* Configures sane default firewall rules
* Configures automatic updates
* Installs ntp to ensure time is synced (tlsdate is no longer available in Debian stable)
* Installs monit and activate config to auto-restart all services
* Installs unbound to reduce the number DNS queries leaving the node
* Helps harden the ssh server
* Gives instructions on what the sysadmin needs to manually do at the end

To use it, set up a Debian server, SSH into it, switch to the root user, and:

```sh
apt-get install -y git
git clone https://github.com/coldhakca/tor-relay-bootstrap.git
cd tor-relay-bootstrap
./bootstrap.sh
```
