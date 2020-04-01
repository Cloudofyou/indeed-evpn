#!/bin/bash

set -x
set -e

check_state(){
if [ "$?" != "0" ]; then
    echo "ERROR Could not bring up last series of devices, there was an error of some kind!"
    exit 1
fi
}

wait_oob_mgmt_server()
{ # Wait function for oob-mgmt-server
  limit=10
  iter=0
  vagrant ssh oob-mgmt-server -c "echo 'ssh successful'"
  while [ $? -gt 0 ] && [ $iter -lt $limit ]
  do
    sleep 5
    echo "Trying to ssh on oob-mgmt-server"
    ((iter++))
    vagrant ssh oob-mgmt-server -c "echo 'ssh successful'"
  done
}

kvm_ok()
{
    set +xe
    lscpu | grep -i virt &> /dev/null
    if [ $? -gt 0 ]; then
        echo "kvm not ok"
    fi
    lsmod | grep -i kvm &> /dev/null
    if [ $? -gt 0 ]; then
        echo "kvm not ok"
    fi
    set -xe
}

echo "Vagrant version is: $(/usr/bin/vagrant --version)"

echo "Libvirt version is: $(/usr/sbin/libvirtd --version)"

echo "Check that the machine supports virtualization..."
kvm_ok

#echo "Installing Vagrant Plugins..."
#vagrant plugin install vagrant-libvirt vagrant-mutate vagrant-scp

#script to clean up libvirt simulations
echo "Cleaning pre-existing simulations"
vms=$(virsh list --all | grep ".*\ simulation_$CI_PROJECT_NAME" | awk '{print $2}')

for item in $vms; do
  echo "$item"
    # check if its powered off state
    vm_state=`virsh list --all | grep $item | awk '{print $3}'`
    if [ "$vm_state" = "running" ] ; then
      virsh destroy $item
    fi
    virsh undefine $item
    virsh vol-delete --pool default $item".img"
done

#rm -rfv .vagrant/
#rm -fv ~/.vagrant.d/data/machine-index/index
