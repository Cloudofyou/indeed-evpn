#!/bin/bash

set -x

cd ./simulation_$CI_PROJECT_NAME

date
vagrant destroy -f /server0/ /leaf/ /spine/ /border/ /fw/

#check that we aren't on cldemo2/master.* project else this will not work because
#the machines are halted from disk image creation
if [ "$CI_PROJECT_NAME" != 'cldemo2' ]
then
  echo "Not on cldemo2 NetQ decomm servers"
  vagrant ssh netq-ts -c "bash /home/vagrant/tests/netq-decommission-inside.sh"
else
  echo "On cldemo2. Check if master.*"
  if [[ "$CI_COMMIT_BRANCH" =~ master ]]
  then
    echo "On cldemo2/master. Do nothing"
  else
    echo "Not on cldemo2/master, we can netq decomm"
    vagrant ssh netq-ts -c "bash /home/vagrant/tests/netq-decommission-inside.sh"
  fi
fi


date
vagrant destroy -f netq-ts oob-mgmt-server oob-mgmt-switch

echo "Finished."
