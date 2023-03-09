#!/bin/sh
iptables -F
iptables -A OUTPUT -j ACCEPT