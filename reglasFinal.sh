#!/bin/sh

iptables -F

#Punto 1
iptables -A OUTPUT -j ACCEPT

#Punto 2
iptables -A INPUT -p tcp --dport 22 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 25 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 110 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 143 -s	 192.168.1.0/24 -j ACCEPT

iptables -A INPUT -p tcp --dport 22 -j DROP
iptables -A INPUT -p tcp --dport 25 -j DROP
iptables -A INPUT -p tcp --dport 110 -j DROP
iptables -A INPUT -p tcp --dport 143 -j DROP

#punto 3 y 4

iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -d 192.168.122.201 -j ACCEPT

iptables -A INPUT -p tcp --dport 443 -j DROP
iptables -A INPUT -p tcp -j DROP

#punto 5
iptables -A INPUT -d 192.168.122.200 -j DROP

