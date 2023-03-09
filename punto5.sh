#!/bin/sh
iptables -F

iptables -A INPUT -d 192.168.122.200 -j DROP