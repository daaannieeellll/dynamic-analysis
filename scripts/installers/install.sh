#!/bin/bash
# Ubuntu VM tools installer

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Set shell to non-interactive
export DEBIAN_FRONTEND=noninteractive

# General upgrade
apt-get install software-properties-common -y
add-apt-repository ppa:cwchien/gradle -y # gradle repo
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
apt-get update

# openjdk 11.0.19, maven 3.6.3, ant 1.10.7, gradle 7.4.2, GNU make 4.3, symlink python
# Procmon  [https://github.com/Sysinternals/ProcMon-for-Linux]
# Sysmon [https://github.com/Sysinternals/SysmonForLinux]
apt-get install build-essential default-jdk maven ant gradle \
    make libnetfilter-queue-dev python-is-python3 python2 python3-pip \
    libssl-dev libffi-dev procmon sysmonforlinux -y

# Fakenet https://github.com/mandiant/flare-fakenet-ng
pip install https://github.com/mandiant/flare-fakenet-ng/zipball/master

# Install psutil python
python3 -m pip install psutil

# Cleanup sysinternals package
rm packages-microsoft-prod.deb
