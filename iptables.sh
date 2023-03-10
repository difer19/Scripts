#!/bin/sh

# Agregar reglas de iptables

iptables -A OUTPUT -j ACCEPT

iptables -A INPUT -p tcp --dport 22 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 25 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 110 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 143 -s	 192.168.1.0/24 -j ACCEPT

iptables -A INPUT -p tcp --dport 22 -j DROP
iptables -A INPUT -p tcp --dport 25 -j DROP
iptables -A INPUT -p tcp --dport 110 -j DROP
iptables -A INPUT -p tcp --dport 143 -j DROP

iptables -A INPUT -p tcp --dport 80 -i eth1 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -i eth2 -j ACCEPT
iptables -A INPUT -i eth1 -j DROP
iptables -A INPUT -i eth2 -j DROP

iptables -A INPUT -p tcp --dport 443 -d 192.168.122.200 -j DROP 
iptables -A INPUT -p tcp --dport 443 -d 192.168.122.201 -j ACCEPT

iptables -A INPUT -d 192.168.122.200 -j DROP

