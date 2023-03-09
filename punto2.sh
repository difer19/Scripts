#!/bin/sh

iptables -F

iptables -A INPUT -p tcp --dport 22 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 25 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 110 -s	 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 143 -s	 192.168.1.0/24 -j ACCEPT

iptables -A INPUT -p tcp --dport 22 -j DROP
iptables -A INPUT -p tcp --dport 25 -j DROP
iptables -A INPUT -p tcp --dport 110 -j DROP
iptables -A INPUT -p tcp --dport 143 -j DROP