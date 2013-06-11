#!/bin/bash

# volume.sh
# Malek Musleh                                                                                                 
# mmusleh@isi.edu                                                                                              
# May. 15, 2013                                                                                               
#                                                                                                           
# (c) 2013 USC/ISI                                                                                        
#                                                                                                             
# This script is provided for a reference only.                                                                    
# Its functional correctness is not guaranteed.                                                                      
# It contains helper functions related to volume usage in Openstack

# Function to get the volume id
function get_volume_id() {

    VOL_NAME=$1
    VOL_ID=$(cinder list | grep $VOL_NAME | head -1 | get_field 1)
    die_if_not_set $LINENO VOL_ID "Failure retrieving volume ID for $VOL_NAME"
    echo $VOL_ID
}

# Function to check if a volume exists
function volume_exists() {

    VOL_NAME=$1
    if [[ -n $(cinder list | grep $VOL_NAME | head -1 | get_field 2) ]]; then
	echo $LINENO "true"
    else
	echo $LINENO "false"
    fi
}

# Function to check the status of a volume
function volume_status() {
    VOL_NAME=$1
    RET=`euca-describe-volumes ${VOL_NAME}`
    status=`echo $RET | awk '{ print $5}'`
    echo ${status}
}

# Function to check the state of a volume
function volume_state() {
    VOL_NAME=$1
    RET=`euca-describe-volumes ${VOL_NAME}`
    status=`echo $RET | awk '{ print $11}'`
    volume=`echo $RET | awk '{ print $2}'`
    user=`echo $RET | awk '{ print $4}'`
    state=`echo $RET | awk '{ print $5}'`
    displayName=`echo $RET | awk '{ print $3}'`
    echo ${status}
}

function volume_attached() {
    VOL_NAME=$1
    status=$(volume_status "${VOL_NAME}")
    state=$(volume_state "${VOL_NAME}")

    if [ "${state}" != "attached" ] && [ "${status}" != "in-use" ]
    then
	echo "false"
    else
	echo "true"
    fi
}

function volume_available() {
    VOL_NAME=$1
    status=$(volume_status "${VOL_NAME}")
    state=$(volume_state "${VOL_NAME}")
    if [ "${state}" != "available" ] || [ "${status}" != "available" ]
    then
        echo "false"
    else
        echo "true"
    fi
}

function detach_volume() {
    VOL_NAME=$1
    RET=`euca-detach-volume ${VOL_NAME}`
    # give some time to detach
    sleep 30
}


function delete_volume() {

    VOL_NAME=$1
    RET=`euca-detach-volume ${VOL_NAME}`
    # give some time to delete
    sleep 30
}

# Call external script to delete all volumes
function delete_all_volumes() {
    local cred_file=$1
    source $cred_file
    echo "Deleting all Volumes using credential file: ${cred_file}"
    python euca-volume-delete-all
    sleep 30
}

##### NOVA VOLUME RELATED FUNCTIONS ######

# Create a volume and wait until it's either error or evailable                                   
function nova_createVolume {
  # will return status as the first parameter                                                                   
  # User credentials for calling nova                                                                           
  local params=$2
  # Volume name                                                                                                
  local vol_name=$3
  # Volume size                                                                                               
  local vol_size=$4

  nova $params volume-create --display_name $vol_name $vol_size
  sleep 4
  local check="nova $params volume-list | grep $vol_name | awk '{ print \$4 }'"
  local status=`eval $check`
  while [ "$status" == "creating" ]; do
    echo "Volume is not ready yet: $status"
    sleep 4
    status=`eval $check`
  done
  eval "$1=$status"
}


# create an instance and wait until it it's ready. If it fails don't return anything to the caller, just exit
function nova_bootInstance {
  local params=$1
  local name=$2
  local flavor=$3
  local image=$4
  local other=$5

  echo "Trying to boot instance $name"
  nova $params boot --flavor $flavor --image $image $other $name
  local check="nova $params list | grep $name | awk '{ print \$6 }'"
  sleep 2
  local status=`eval $check`
  while [ "$status" == "BUILD" ]; do
    echo "Building instance: $status"
    sleep 5
    status=`eval $check`
  done
  if [ "$status" != "ACTIVE" ];
  then
     echo "Failed to start instance $name $flavor $image: $status"
     exit -100
  fi
}

# Attach volume.                                                                                                
function nova_attachVolume {
  local params=$1
  local instance=$2
  local volume_name=$3
  local device=$4

  echo "Trying to attach volume $volume_name to $instance"

  local volume_id=""
  nova_getVolumeField volume_id $volume_name "$params" 2
  if [ "$volume_id" == "" ];
  then
     echo "Volume $volume_name is not found, cannot attach"
  else
     nova $params volume-attach $instance $volume_id $device
     sleep 30
  fi
}

function nova_detachVolume {
  local params=$1
  local instance=$2
  local volume_id=""
  echo "Trying to detach volume $3 from $instance"

  nova_getVolumeField volume_id $3 "$params" 2
  nova $params volume-detach $instance $volume_id
  sleep 10
}

# Get attachement instance of volume $2. Return as 1  
function nova_attachedTo {
  nova_getVolumeField $1 $2 "$3" 12
}

function nova_getVolumeField {
  local vol_name=$2
  local params=$3
  local index=$4
  local check=`nova $params volume-list | grep $2 | awk -v a="$index" '{ print \$a }'`
  eval "$1=$check"
}

function nova_volumeStatus {
  nova_getVolumeField $1 $2 "$3" 4
}

