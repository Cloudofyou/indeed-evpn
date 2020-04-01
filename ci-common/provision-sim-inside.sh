#!/bin/bash

set -x

function error() {
  echo -e "\e[0;33mERROR: Provisioning if the simulation failed while running the command $BASH_COMMAND at line $BASH_LINENO.\e[0m" >&2
  exit 1
}

trap error ERR

cd /home/vagrant/automation

# Enable Colored Output when Running Ansible in the CI pipeline
export ANSIBLE_FORCE_COLOR=true

echo "#### Running Deployment Playbook... ###"
#already in the automation directory on the guest machine
ansible-playbook playbooks/deploy.yml -i inventories/pod1 --diff
