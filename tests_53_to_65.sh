#!/bin/bash
# set -x

source functions.sh
source volume.sh

# kvm-fs kvm_fs or whatever works
KVM_IMAGE=kvm_fs
KVM_FLAVOR=1
INST_KVM_NAME=test54
INST_BAD_NAME=test55

KEY_FILE="/root/testKey5365"
KEY_PAIR="testKey5365"

USER1_PARAM="--os-username admin --os-password secrete --os-tenant demo --os-auth-url http://127.0.0.1:5000/v2.0/"
USER2_PARAM="--os-username glance --os-password glance --os-tenant service --os-auth-url http://127.0.0.1:5000/v2.0/"

VOL_GOOD_NAME=test53
VOL_SIZE=1
DEV_NAME="/dev/vdb"
VOL_BAD_NAME=test56

function tests_53_to_65() {

########################################################################################################
########################################################################################################
########################################################################################################

# 53 nova user: create a volume 
# : nova volume-create --display_name <volume_name> <size_in_GB>, Check with nova volume-list



    STATUS=""
    nova_createVolume STATUS "$USER1_PARAM" $VOL_GOOD_NAME $VOL_SIZE
    if [ "$STATUS" == "available" ];
    then
	echo "PASSED Test 53: volume creation. Got status $STATUS"
    else
	echo "FAILED Test 53: volume creation. Got status $STATUS"
    fi 

########################################################################################################
# 54 nova user attach a volume and add contents 
# : nova volume-attach <instance_id> <volume_id> <device>, Check with nova volume-list, 
# for kvm - make a linux-type partition and format it with ext3 fs.  
# http://docs.openstack.org/trunk/openstack-compute/admin/content/managing-volumes.html, 
# for lxc- volume auto-mounted at /vmnt

    makeAddKey $KEY_PAIR $KEY_FILE "$USER1_PARAM"
    nova_bootInstance "$USER1_PARAM" $INST_KVM_NAME $KVM_FLAVOR $KVM_IMAGE "--key-name $KEY_PAIR"
    KVM_IP=`nova $USER1_PARAM list | grep $INST_KVM_NAME | awk '{ print \$8 }' | sed 's/public=//'`
    
    echo "Got IP for KVM $KVM_IP"
    # Wait until the network is up in the guest
    echo "Waiting for the guest to boot"
    sleep 40

    echo "Looking for /dev/vdb before attaching: $STATUS"
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "ls /dev/vdb"
    
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    echo "Status of freshly created volume: $STATUS"
    nova_attachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_GOOD_NAME $DEV_NAME
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    echo "Status of volume after attaching: $STATUS"
    
    
    ## KVM part: make ext3 fs partition and format it
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "ls /dev/vdb"
    echo "Looking for /dev/vdb after attaching: $STATUS"
    
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "mkfs -t ext3 /dev/vdb"
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "mount /dev/vdb /mnt"
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "echo Hello > /mnt/Hello.txt"
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "cat /mnt/Hello.txt"
    
    if [ "$STATUS" == "Hello" ];
    then
	echo "PASSED Test 54: Format, write and read back"
    else
	echo "FAILED Test 54: Read back $STATUS"
    fi
    
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "umount /mnt"


    ## LXC part
    ## TODO

    # Undo volume attach. Also works as test 60
    # 60 nova user: detach a volume 
    # : nova volume-detach <instance_id> <volume_id>, Check with nova volume-list
    nova_detachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_GOOD_NAME
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    if [ "$STATUS" != "available" ];
    then
	echo "FAILED test 60: Volume status $STATUS"
    else
	echo "PASSED test 60: After detachment volume status is $STATUS"
    fi
  

    ########################################################################################################
    # 55 nova user: attach a volume to an unauthorized instance 
    # : tried to attach a volume to an instance created by a different user in a different tenant - failed

    nova_bootInstance "$USER2_PARAM" $INST_BAD_NAME $KVM_FLAVOR $KVM_IMAGE ""
    
    echo "Errors are okay: this is a denial test"
    nova_attachVolume "$USER1_PARAM" $INST_BAD_NAME $VOL_GOOD_NAME $DEV_NAME
    nova_attachedTo STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    if [ "$STATUS" == "$INST_BAD_NAME" ];
    then
	echo "FAILED: Volume actually attached (test55): $STATUS"
    else
	echo "PASSED test 55: attachment to unauthorized instance failed: $STATUS"
    fi

    # Clean up: kill the instance
    echo "Deleting instance $INST_BAD_NAME"
    nova $USER2_PARAM delete $INST_BAD_NAME 
    

    # Now have good volume detached and available, kvm instance running.
    #
    ########################################################################################################
    # 56 nova user: attach an unauthorized volume to an instance 
    # : tried to attach a volume created by other user in other tenant - failed

    nova_createVolume STATUS "$USER2_PARAM" $VOL_BAD_NAME $VOL_SIZE
    if [ "$STATUS" != "available" ];
    then
	echo "Failed to create valume for test 56: got status $STATUS"
    fi 
    
    echo "Errors are okay: this is a denial test"
    nova_attachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_BAD_NAME $DEV_NAME
    nova_attachedTo STATUS $VOL_BAD_NAME "$USER2_PARAM"
    if [ "$STATUS" == "$INST_KVM_NAME" ];
    then
	echo "FAILED: Volume actually attached (test56): $STATUS"
    else
	echo "PASSED test 56: attachment of unauthorized volume failed: $STATUS"
    fi
    
    # Clean up: kill the volume, also test 64
    # 64 nova user: delete a volume : nova volume-delete <volume-id>, Check with nova volume-list
    nova $USER2_PARAM volume-delete $VOL_BAD_NAME
    sleep 20
    STATUS=`nova $USER2_PARAM volume-list | grep $VOL_BAD_NAME`
    if [ "$STATUS" == "" ];
    then
	echo "PASSED Test 64: volume deletion"
    else
	echo "FAILED Test 64: volume delete: $STATUS"
    fi


    ########################################################################################################
    # 57 nova user: attach an existing volume and verify contents 
    # 58 nova user: attach an existing volume and verify contents 

    nova_attachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_GOOD_NAME $DEV_NAME
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    if [ "$STATUS" == "in-use" ];
    then
	echo "Volume reattach (test57 kvm) succeeded"
    else
	echo "Volume reattach (test57 kvm) failed. Volume status is $STATUS"
    fi
    
    ## Check contents
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "mount /dev/vdb /mnt"
    sendSshAndGet STATUS $KEY_FILE $KVM_IP "cat /mnt/Hello.txt"
    if [ "$STATUS" == "Hello" ];
    then 
	echo "PASSED Test 57: Read content from reattached volume"
    else
	echo "FAILED Test 57: Reading reattached volume: $STATUS"
    fi
    
    
    ########################################################################################################
    # 59 nova user: create multiple volumes
    # ?? No appropriate nova command found

    ########################################################################################################

    # 61 nova user: reattach a volume 
    # : nova volume-attach <instance_id> <volume_id> <mount_point>, Check with nova volume-list. 
    # NOTE: KVM does not reuse /dev/vd? letter. It increments to next letter.
    # Same as 57???


    ########################################################################################################
    # 62 nova user: detach an unauthorized volume from an instance : operation failed
    # At this point VOL_GOOD_NAME is attached by user1
    # 63 nova user: detach a volume from an unauthorized instance : operation failed


    # User 2 does detach, user 1 (owner) checks
    echo "Errors are okay: this is a denial test"
    nova_detachVolume "$USER2_PARAM" $INST_KVM_NAME $VOL_GOOD_NAME
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    if [ "$STATUS" == "in-use" ];
    then
	echo "PASSED test 62/63 (unauthorized volume detach): Volume still attached"
    else
	echo "FAILED test 62/63 (unauthorized volume detach): After detachment volume is $STATUS"
    fi

    ########################################################################################################
    # 65 nova user: delete an unauthorized volume : operation failed 

    # User 2 does delete, user 1 (owner) checks
    echo "Errors are okay: this is a denial test"
    nova $USER2_PARAM volume-delete $VOL_GOOD_NAME
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    if [ "$STATUS" != "" ];
    then
	echo "PASSED test 65 (unauthorized volume delete): Volume still there $STATUS"
    else
	echo "FAILED test 65 (unauthorized volume delete): Volume is gone"
    fi

    # Clean up
    nova_detachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_GOOD_NAME
    nova $USER1_PARAM volume-delete $VOL_GOOD_NAME
    nova $USER1_PARAM delete $INST_KVM_NAME
    nova $USER1_PARAM keypair-delete $KEY_PAIR
    rm -f $KEY_FILE
    rm -f "$KEY_FILE.pub"

}