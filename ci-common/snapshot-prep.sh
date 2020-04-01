#!/bin/bash
#

## setup env
set -e
set -x

cd simulation_$CI_PROJECT_NAME

# change the config-key to a non-functional key
vagrant ssh netq-ts -c 'netq install opta activate-job config-key CMScARImZ3cuYWlyZGV2MS5uZXRxZGV2LmN1bXVsdXNuZXR3b3Jrcy5jb20YuwM='

# clear syslog
vagrant ssh netq-ts -c 'sudo truncate -s 0 /var/log/syslog' 

#stage netq.yml for the network nodes
vagrant ssh oob-mgmt-server -c "ansible leaf:spine:exit -a 'wget -O /etc/netq/netq.yml http://192.168.200.1/netq.yml' -b"

#stage netq.yml for servers (no vrf)
vagrant ssh oob-mgmt-server -c "ansible server0* -a 'wget -O /etc/netq/netq.yml http://192.168.200.1/netq-server.yml' -b"

#stage netq.yml for oob-mgmt-server (no vrf)
vagrant ssh oob-mgmt-server -c "sudo cp /var/www/html/netq-server.yml /etc/netq/netq.yml"

#shutdown everything except oob-mgmt-server and netq-ts from inside the sim
vagrant ssh oob-mgmt-server -c "ansible leaf:spine:exit:server0* -B 1 -P 0 -a 'shutdown -h now' -b"

vagrant halt netq-ts
vagrant halt oob-mgmt-switch
vagrant halt oob-mgmt-server

