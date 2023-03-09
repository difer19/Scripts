#!/bin/sh
iptables -F
iptables -A INPUT -p tcp --dport 443 -d 192.168.122.200 -j DROP 
iptables -A INPUT -p tcp --dport 443 -d 192.168.122.201 -j ACCEPT