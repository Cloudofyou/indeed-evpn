#!/bin/bash
#
# Only runs in topology repos. Calls script that runs ansible playbook to provision the golden standard topology

set -x

function error() {
  echo -e "\e[0;33mERROR: Provisioning of the simulation failed while running the command $BASH_COMMAND at line $BASH_LINENO.\e[0m" >&2
  if [ "$debug" != "true" ]; then
    echo " >>>Destroying Simulation<<<"
    vagrant destroy -f
  fi
  exit 1
}

trap error ERR

source ./cldemo2/ci-common/pipeline_failure_behavior

cd ./simulation_$CI_PROJECT_NAME

# Force Colored output for Vagrant when being run in CI Pipeline
export VAGRANT_FORCE_COLOR=true

vagrant ssh oob-mgmt-server -c "bash /home/vagrant/tests/provision-sim-inside.sh"
