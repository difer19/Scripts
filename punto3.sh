#!/bin/sh

iptables -F

iptables -A INPUT -p tcp --dport 80 -i eth1 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -i eth2 -j ACCEPT
iptables -A INPUT -i eth1 -j DROP
iptables -A INPUT -i eth2 -j DROP