#!/bin/bash

# Automated provisioning script run as the `root` user by `vagrant up`
# -- see `./Vagrantfile`.

set -e

install_packages() {
  local packages
  # X11 environment so that you can use `ximagesink`
  packages=lubuntu-desktop
  # VirtualBox guest additions for shared folders, USB, window resizing, etc.
  packages+=" virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11"
  # For building stbt and running the self-tests
  packages+=" expect git pep8 pylint python-docutils python-nose"
  # For the Hauppauge HDPVR
  packages+=" gstreamer1.0-libav v4l-utils"

  apt-get install -y $packages
}

apt-get update
install_packages || {
  /usr/share/debconf/fix_db.pl  # https://bugs.launchpad.net/ubuntu/+bug/873551
  install_packages
}

apt-get install -y software-properties-common  # for "add-apt-repository"
add-apt-repository -y ppa:stb-tester/stb-tester
apt-get update
apt-get install -y stb-tester

DEBIAN_FRONTEND=noninteractive apt-get install -y lirc
sed -i \
    -e 's,^START_LIRCD="false",START_LIRCD="true",' \
    -e 's,^REMOTE_DEVICE=".*",REMOTE_DEVICE="/dev/lirc0",' \
    /etc/lirc/hardware.conf
service lirc start
# You still need to install /etc/lirc/lircd.conf with a description of your
# remote control's infrared protocol. See http://stb-tester.com/lirc.html

# HDPVR and other V4L devices
usermod -a -G video vagrant

# VidiU (RTMP streaming device)
apt-get install -y crtmpserver
[ -f /etc/crtmpserver/crtmpserver.lua.orig ] ||
    cp /etc/crtmpserver/crtmpserver.lua{,.orig}
cp /vagrant/crtmpserver.lua /etc/crtmpserver/
service crtmpserver restart &>/dev/null </dev/null ||
    echo error restarting crtmpserver >&2
service ufw stop &>/dev/null </dev/null || echo error stopping ufw firewall >&2

sudo su - vagrant /vagrant/setup-vagrant-user.sh
