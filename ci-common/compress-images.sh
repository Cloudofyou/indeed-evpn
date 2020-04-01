#!/bin/bash

image_dest_folder=`cat ci-common/snapshots.sh | grep ^image_dest_folder= | cut -d'=' -f2 | tr -d '"'`

if [ -z "$image_dest_folder" ]
then
  echo "Fail: Couldn't detect where the source image folder is"
  exit 1
fi

for f in `find ${image_dest_folder} -type f | grep '........-....-....-....-............$'`
do
  echo "Converting & compressing ${f} file to ${f}.qcow2"
  qemu-img convert -c -O qcow2 "${f}" "${f}.qcow2"&
done

wait

echo "All converting and compressing finished"

for f in `find ${image_dest_folder} -type f ! -name "*.*"`
do
  echo "cleaning up ${f}"
  rm ${f}
done
