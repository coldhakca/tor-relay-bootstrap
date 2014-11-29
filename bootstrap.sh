#!/bin/bash

# check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# update software
echo "== Updating software"
sudo apt-get update
sudo apt-get dist-upgrade -y

# add official Tor repository
if ! grep -q "http://deb.torproject.org/torproject.org" /etc/apt/sources.list; then
    echo "== Adding the official Tor repository"
    echo "deb http://deb.torproject.org/torproject.org `lsb_release -cs` main" >> /etc/apt/sources.list
    gpg --keyserver keys.gnupg.net --recv 886DDD89
    gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
fi

# install tor and related packages
echo "== Installing Tor and related packages"
    apt-get update
apt-get install deb.torproject.org-keyring tor tor-arm

# todo: configure automatic updates
# todo: configure firewall rules
