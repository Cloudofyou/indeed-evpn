#!/bin/bash

set -e
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

source ./tests/pipeline_failure_behavior

echo "Starting to run tests...."

cd ./simulation_$CI_PROJECT_NAME

# Force Colored output for Vagrant when being run in CI Pipeline
export VAGRANT_FORCE_COLOR=true

# Perform netq tests from netq-ts
vagrant ssh netq-ts -c "bash /home/vagrant/tests/tests-netq-ts-inside.sh"
