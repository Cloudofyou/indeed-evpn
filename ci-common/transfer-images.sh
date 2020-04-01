#!/bin/bash

set -e

echo "Detecting where the image build folder is"
image_dest_folder=`cat ci-common/snapshots.sh | grep ^image_dest_folder= | cut -d'=' -f2 | tr -d '"'`

if [ -z "$image_dest_folder" ]
then
  echo "Fail: Couldn't detect where the source image folder is"
  exit 1
fi

# transfers images in parallel 
python3 ./ci-common/image-transfer.py

#b2 authorize-account $B2_KEY_ID $B2_KEY
#b2 sync --threads 50 $image_dest_folder b2://air-production-templates

echo "Image transfer done"

#delete the images in the folder
echo "Cleanup the image build directory"

rm ${image_dest_folder}/*.qcow2
