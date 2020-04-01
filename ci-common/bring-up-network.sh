#!/bin/bash
#

set -x

# Force Colored output for Vagrant when being run in CI Pipeline
export VAGRANT_FORCE_COLOR=true

check_state(){
if [ "$?" != "0" ]; then
    echo "ERROR Could not bring up last series of devices, there was an error of some kind!"
    exit 1
fi
}

#echo "Currently in directory: $(pwd)"

cd simulation_$CI_PROJECT_NAME

echo "#####################################"
echo "#   Starting all Spines...          #"
echo "#####################################"
vagrant up spine01 spine02 spine03 spine04
check_state

echo "#####################################"
echo "#   Starting all Leafs...           #"
echo "#####################################"
vagrant up leaf01 leaf02 leaf03 leaf04
check_state

echo "#####################################"
echo "#   Starting Service/Border Leafs...#"
echo "#####################################"
vagrant up border01 border02 fw1 fw2
check_state

echo "#####################################"
echo "#   Starting all Servers...         #"
echo "#####################################"
vagrant up server01 server02 server03 server04
vagrant up server05 server06 server07 server08
check_state

echo "#####################################"
echo "#   Status of all simulated nodes   #"
echo "#####################################"
vagrant status

exit 0
