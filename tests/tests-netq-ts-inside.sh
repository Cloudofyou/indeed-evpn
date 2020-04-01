#!/bin/bash

check_state(){
if [ "$?" != "0" ]; then
    echo "ERROR Previous command failed test!"
    exit 1
fi
}
echo "Agent register & NetQ processing time"
sleep 60

echo "netq show agents"
netq show agents 
check_state

echo "netq check agents include 0"
netq check agents include 0

echo "netq check interfaces"
netq check interfaces include 0
check_state
netq check interfaces include 1
check_state
netq check interfaces include 2
check_state
netq check interfaces include 3
check_state

echo "netq check mtu"
netq check mtu
check_state
netq check mtu include 0
check_state
netq check mtu include 1
check_state
netq check mtu include 2
check_state

echo "netq check vlan"
netq check vlan
check_state
netq check vlan include 0
check_state
netq check vlan include 1
check_state

echo "netq check ntp"
netq check ntp
check_state
netq check ntp include 0
check_state

