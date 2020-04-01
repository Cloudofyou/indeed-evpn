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

if [ "$CI_PROJECT_NAME" = "cldemo2" ]
then
  cp -r simulation simulation_$CI_PROJECT_NAME
  cd simulation_$CI_PROJECT_NAME
else
  cp -r cldemo2/simulation simulation_$CI_PROJECT_NAME
  cd simulation_$CI_PROJECT_NAME
fi

#set wbid to project concurrency_id so parallel projects' links do not collide
sed -i "s/wbid\ =\ .*/wbid\ =\ $CONCURRENCY_ID/" Vagrantfile
egrep 'wbid\ =\ ' Vagrantfile

echo "#####################################"
echo "#   Starting the MGMT Server...     #"
echo "#####################################"
vagrant up oob-mgmt-server oob-mgmt-switch netq-ts
check_state

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

ip_address=$(vagrant ssh-config oob-mgmt-server | grep HostName | awk '{print $2}')

echo "#####################################"
echo "#   Status of all simulated nodes   #"
echo "#####################################"
vagrant status

echo "Detected $ip_address for the OOB-MGMT-SERVER"
echo "Currently in directory: $(pwd)"

echo "Creating netq decomm script from cldemo2.dot"
echo "#!/bin/bash" > ../tests/netq-decommission-inside.sh 
grep function cldemo2.dot | cut -d'"' -f 2 | sed 's/^/netq decommission /' >>../tests/netq-decommission-inside.sh 

#Copy in the test scripts
echo "Copy test scripts directory to oob-mgmt-server for testing"
vagrant scp ../tests oob-mgmt-server:/home/vagrant
check_state

echo "Copy test scripts directory to netq-ts for testing"
vagrant scp ../tests netq-ts:/home/vagrant
check_state

# automation only happens in the topology repos
# so if we're on cldemo2, skip this
if [ "$CI_PROJECT_NAME" != "cldemo2" ]
then
  echo "Copy automation to oob-mgmt-server for provisioning"
  vagrant scp ../automation oob-mgmt-server:/home/vagrant
  check_state
fi

echo "List directory /home/vagrant on oob-mgmt-server"
vagrant ssh oob-mgmt-server -c "ls -lha /home/vagrant"

echo "List directory /home/vagrant on netq-ts"
vagrant ssh netq-ts -c "ls -lha /home/vagrant"
