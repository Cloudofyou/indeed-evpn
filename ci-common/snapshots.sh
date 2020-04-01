#!/bin/bash
#
# This script creates disk images for AIR for a cldemo2 CI pipeline run
# This entails Making an API call to AIR to create the image metadata to return a UUID.
# The disk images get copied to a local folder with the UUID as the name
# The next stage in CI performs the image transfer
#
# Only supports Ubuntu and Cumulus VX
#
# needs env variables set
# - export AIR_USERNAME=<username>
# - export AIR_PASSWORD=<password>
#
# needs jq installed
# - sudo apt-get install jq
#

## setup env
set -e

# this is the temp storage for the qcow disk images we need to create
image_dest_folder="/mnt/nvme/air-image-builds/"
#
# set some variables/settings
air_auth_url="https://air.cumulusnetworks.com/api/v1/login/"
air_images_url="https://air.cumulusnetworks.com/api/v1/image/"

### generates data for AIR auth via curl
generate_auth_post_data()
{
  cat <<EOF
  {
    "username": "$AIR_USERNAME",
    "password": "$AIR_PASSWORD"
  }
EOF
}

### generates data for image create
#pass in a name as $1 then the partition where / is mounted such as "/dev/sda1"
generate_air_image_create_data()
{
  cat <<EOF
  {
    "name": "$1",
    "base": "true",
    "mountpoint": "$2",
    "agent_enabled": "true"
  }
EOF
}

#Before we get started, check to see if the image_dest_folder is empty.
#Mixing images from jobs in there is no good. If it's not empty, bail out so we can find out why and manually clean it up.
if [ -z "$(ls -A $image_dest_folder)" ]; then
   echo "Directory is empty, we good"
else
  echo "Error: Detected that the image build directory $image_dest_folder is not empty. It needs to be empty."
  exit 1
fi

cd simulation_$CI_PROJECT_NAME
parent_folder=$(basename "`pwd`")

## vagrant creates libvirt domains with the name set to (parent-folder-of-Vagrantfile)_boxname
# This makes a list of all of the virsh domains (VMs) that Vagrant created for us
# We'll loop through this list $vm_images and work on each one in serial
vm_images=`virsh vol-list default | grep "${parent_folder}_" | awk '{print $2}'`

#### put in a check here to fail if we didn't find anything to clone if vm_images is unexpected

## get air auth token before we enter loop
# curl -f fails and exits if http error
curl_output=`curl -f --header "Content-Type: application/json" \
  --request POST \
  --data "$(generate_auth_post_data)" \
  $air_auth_url`

## parse out auth token
auth_token=`echo $curl_output | jq '.["token"]' | sed -e 's/^"//' -e 's/"$//'`

### check auth token/sanity checks make sure we didn't pickup garbage or something
if [ -z "$auth_token" ]
then
  echo "Fail: detected auth token empty is empty"
  exit 1
fi
token_length=`expr length $auth_token`
if [ "$token_length" != "189" ]
then
  echo "Fail: auth_token seems to be the wrong size?"
  exit 1
fi

for image in $vm_images; do
  echo "Working on $image"

  #this is the complete filename of the .img file at the end of the absolute path in $image
  libvirt_filename=`basename $image`
  libvirt_domain_name=`basename -s .img "$libvirt_filename"`

  image_name="${CI_PIPELINE_ID}:${CI_COMMIT_SHORT_SHA}:${libvirt_domain_name}.qcow2"

  #coelesces the image with backing image into a single file, stays in the libvirt storage next to original file/vm
  echo "making virt-clone inside of libvirt storgage pool"
  virt-clone --original "$libvirt_domain_name" --name "${libvirt_domain_name}_${CI_PIPELINE_ID}" --auto-clone
  echo "removing/undefining that clone right away"
  virsh undefine "${libvirt_domain_name}_${CI_PIPELINE_ID}" #remove this as an installed VM right away: it'll never run here

  echo "moving cloned image out of libvirt storage"
  #move the file out of libvirt storage to avoid permissions heck.
  virsh vol-download --pool default "${libvirt_domain_name}_${CI_PIPELINE_ID}.img" "${image_dest_folder}${libvirt_domain_name}_${CI_PIPELINE_ID}.qcow2"
  #now remove that intermediary clone. don't need it
  echo "deleting that intermediary clone. clean up"
  virsh vol-delete --pool default "${libvirt_domain_name}_${CI_PIPELINE_ID}.img" 

  #extremely quick n dirty OS check. VX image size is 6.0GB according to qemu-img info
  #if it's 6.0GB, then its VX, if not Ubuntu. This matters for the mountpoint we have to provide to AIR. AIR needs to know dev/partition of /
  #The need for this may go away, we'll see.
  vdisk_size=`qemu-img info "${image_dest_folder}${libvirt_domain_name}_${CI_PIPELINE_ID}.qcow2" | grep "^virtual size:" | cut -d":" -f2 | sed -e 's/^[[:space:]]*//' | cut -d" " -f1`
  if [ "$vdisk_size" == "6.0G" ]; then
    #this is vx
    echo "detected vx image. setting mountpoint"
    mountpoint="/dev/sda4"
  else
    echo "detected else assuming ubuntu setting mountpoint"
    #this is ubuntu
    mountpoint="/dev/sda3"
  fi

  echo "Making API call for image add, getting UUID"
  curl_output=`curl -f --header "Content-Type: application/json" \
      --header "Authorization: Bearer $auth_token" \
      --request POST \
      --data "$(generate_air_image_create_data $image_name $mountpoint)" \
      $air_images_url`
  UUID=`echo $curl_output | jq '.["id"]' | sed -e 's/^"//' -e 's/"$//'`

  echo "renaming ${image_dest_folder}${libvirt_domain_name}_${CI_PIPELINE_ID}.qcow2 as: ${image_dest_folder}${UUID}"
#  qemu-img convert -c -O qcow2 "${image_dest_folder}${libvirt_domain_name}_${CI_PIPELINE_ID}.qcow2" "${image_dest_folder}${UUID}.qcow2"
#  echo "delete the inflated copy: ${image_dest_folder}${libvirt_domain_name}_${CI_PIPELINE_ID}.qcow2"
  mv "${image_dest_folder}${libvirt_domain_name}_${CI_PIPELINE_ID}.qcow2" "${image_dest_folder}${UUID}"

done

echo "Done"
exit 0
