#!/bin/bash
sudo apt update
sudo apt upgrade
sudo apt install wget unzip vim curl gcc openssl build-essential libgd-dev libssl-dev libapache2-mod-php php-gd php apache2
export VER="4.4.6"
curl -SL https://github.com/NagiosEnterprises/nagioscore/releases/download/nagios-$VER/nagios-$VER.tar.gz | tar -xzf -
# cd nagios-4.4.6
# ./configure
# sudo make all
# sudo make install-groups-users
# sudo usermod -a -G nagios www-data
# sudo make install
# cd /lib/systemd/system
# sudo make install-init
# cd /usr/src/
# sudo make install-commandmode
# cd /usr/local/nagios/etc/
# sudo make install-config
# sudo make install-webconf
# sudo a2enmod rewrite cgi
# sudo systemctl restart apache2
# sudo make install-exfoliation
#sudo htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
#sudo systemctl enable --now nagios
#sudo systemctl status nagios
