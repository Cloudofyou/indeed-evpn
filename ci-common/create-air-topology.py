#!/usr/bin/env python

#
# Creates a new topology instance on AIR
# Starting with an example json file, we have to find the UUID/ID of the image that we put there in a previous CI stage
# When AIR responds with the UUID/ID we update it in our json variable
# Once we've built the json topology file, we create the instance on AIR.
#

import os
import requests
import json
import sys
import re


topology_mgmt_url = "https://air.cumulusnetworks.com/api/v1/topology/"
image_mgmt_url = "https://air.cumulusnetworks.com/api/v1/image/"
org_mgmt_url = "https://air.cumulusnetworks.com/api/v1/organization/"
login_url = "https://air.cumulusnetworks.com/api/v1/login/"
simulation_mgmt_url = "https://air.cumulusnetworks.com/api/v1/simulation/"

air_username=os.getenv('AIR_USERNAME')
air_password=os.getenv('AIR_PASSWORD')

ci_pipeline_id = os.getenv('CI_PIPELINE_ID')
ci_project_name = os.getenv('CI_PROJECT_NAME')
ci_commit_short_sha = os.getenv('CI_COMMIT_SHORT_SHA')

target_org_name = "Cumulus Networks"

#regex string that will help us find the images on AIR, by name for this pipeline run
regex_txt = "^" + ci_pipeline_id + ":" + ci_commit_short_sha + ":.*.qcow2$"
#print ("regex string: " + regex_txt)

#init the login post data
login = {
  "username": air_username,
  "password": air_password
}

##topology POST data initilize
# This is what we'll end up sending in the HTTP POST to create the topology instance
# This gets populated, initially, by the example json topology file included
topology_post_data = {}

### Try to login
try:
  auth_response = requests.post(url=login_url,json=login)
  auth_response.raise_for_status()
except requests.exceptions.HTTPError as err:
  print("Error in auth to AIR")  
  print(err)
  sys.exit(1)

# Build the HTTP header now that we have the auth token
# only Authorization at the moment
headers = {
  "Authorization": "Bearer " + auth_response.json()["token"]
}

### open the existing json topology
##step through each node. 
# build regex for that node for name
# walk through list of air images (download once)
# find UUID
# replace UUID for the current node

#this feteches all the images on AIR (do this only once)
try:
  air_images_response = requests.get(url=image_mgmt_url,headers=headers)
  air_images_response.raise_for_status()
  air_images = air_images_response.json()
except requests.exceptions.HTTPError as err:
  print("HTTP Error fetching images")  
  print(err)
  sys.exit(1)


#Get ready to open/read the json topology template included here
images_path=""
this_script_dir = os.path.dirname(__file__)
file_to_open="air-topology.json"
abs_file_path=os.path.join(this_script_dir, file_to_open)

#open the existing topo definition and load into the POST data var
with open(abs_file_path) as json_file:
  topology_post_data = json.load(json_file)

#the nodes value is a list, so we just have the index to deal with.
# We have to init a counter, so we can change the existing value 
index=0
for nodes in topology_post_data['nodes']:
  print("Working on: " + nodes['name'])

  #build the search string to find the images for this job (from prev CI stage/job) 
  regex_txt="^"+ci_pipeline_id+":"+ci_commit_short_sha+".*_"+nodes['name']+".qcow2$"

  # loop through the downloaded list of air images, match by name, save UUID
  # replace the existing UUID.
  for air_image_entry in air_images:
    if re.match(regex_txt, air_image_entry["name"]) is not None:
      print ("Found AIR Image: " + air_image_entry["name"] + " with UUID: " + air_image_entry['id'])
      print ("About to replace: " + topology_post_data['nodes'][index]['name'])
      topology_post_data['nodes'][index]['os'] = air_image_entry['id']
      print ("changed:" + json.dumps(topology_post_data['nodes'][index],indent=4))

  index = index+1
  #print(json.dumps(response.json(),indent=4))

## end for nodes loop

#update the topology name
#topology_post_data['name'] = ci_pipeline_id + ":" + ci_commit_short_sha + ":" + ci_project_name

#go find the org ID/UUID so we can set it 
try:
  org_fetch_response = requests.get(url=org_mgmt_url,headers=headers)
  org_fetch_response.raise_for_status()
  air_orgs = org_fetch_response.json()
except requests.exceptions.HTTPError as err:
  print("HTTP Error fetching images")  
  print(err)
  sys.exit(1)

for org in air_orgs:
  if org["name"] == target_org_name:
    print("Found our org. Get ID")
    org_id = org["id"]
    print("Org: " + target_org_name + " | UUID/ID: " + org_id)

topology_post_data["organization"] = org_id

#####
print ("Done manipulating topology definition with new UUID/OS strings")
print ("New Topology Definition: " + json.dumps(topology_post_data,indent=4))

### sanity check that there is a UUID ("os") for each node in the json here

#loop through all the nodes in the json and make sure the os string makes sense
for nodes in topology_post_data['nodes']:
  print("Working on: " + nodes['name'])
  if len(nodes["os"]) < 36:
    print ("failed sanity check on json before create on air. Check the new topology definition above")
    sys.exit(0)
  else:
    print (nodes["name"] + " looks good with UUID: " + nodes["os"])

#post the topology to create it.
try:
  air_topo_response = requests.post(url=topology_mgmt_url,headers=headers,json=topology_post_data)
  air_topo_response.raise_for_status()
  air_topo_response = air_topo_response.json()
except requests.exceptions.HTTPError as err:
  print("HTTP Error submitting the topology")  
  print(err)
  sys.exit(1)

print ("Response from AIR: " + json.dumps(air_topo_response,indent=4))

#create an instance of the topology as a simulation

print ("Creating the simulation instance from the topology")
print ("The topology URL to invoke the sim is: " + air_topo_response["url"])

#init the login post data
simulation = {
  "topology": air_topo_response["url"],
  "name": ci_pipeline_id+":"+ci_commit_short_sha+":"+"cldemo2"
}

try:
  air_sim_response = requests.post(url=simulation_mgmt_url,headers=headers,json=simulation)
  air_sim_response.raise_for_status()
  air_sim_response = air_sim_response.json()
except requests.exceptions.HTTPError as err:
  print("HTTP Error submitting the simulation instance")
  print(err)
  sys.exit(1)

print ("Response from AIR: " + json.dumps(air_sim_response,indent=4))

sys.exit(0)



