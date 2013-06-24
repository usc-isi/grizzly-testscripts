#!/bin/bash
set -x

source functions.sh
source volume.sh
source glance.sh

KVM_FLAVOR=1
INST_KVM_NAME=test54
INST_BAD_NAME=test55

KEY_FILE="./testKey5365"
KEY_PAIR="testKey5365"

USER1_PARAM=""
#"--os-username demo1 --os-password demo1_secrete --os-tenant demo_tenant1 --os-auth-url http://127.0.0.1:5000/v2.0/"
USER2_PARAM=""
#"--os-username demo2 --os-password demo2_secrete --os-tenant demo_tenant2 --os-auth-url http://127.0.0.1:5000/v2.0/"

VOL_GOOD_NAME=test53
VOL_SIZE=1
DEV_NAME=""
DEV_LETTERS=""
VMNT_NAME=""
#"/dev/vdb"
VOL_BAD_NAME=test56

function tests_53_to_65() {

    local log=$1
    local IMAGE=$2
    local HYPERVISOR=$3
    local TIMEOUT=$4
    local USER=$5
    local msg

    # Pick settings
    KVM_FLAVOR=${FLAVOR}
    source ${OPENRC_DEMO1}
    USER1_PARAM="--os-username $OS_USERNAME --os-password $OS_PASSWORD --os-tenant $OS_TENANT_NAME --os-auth-url $OS_AUTH_URL"
    source ${OPENRC_DEMO2}
    USER2_PARAM="--os-username $OS_USERNAME --os-password $OS_PASSWORD --os-tenant $OS_TENANT_NAME --os-auth-url $OS_AUTH_URL"

    if [ "$HYPERVISOR" == "kvm" ]
    then
	DEV_LETTERS="vd"
    else
	DEV_LETTERS="sd"
    fi
    DEV_NAME="/dev/${DEV_LETTERS}b"
    VMNT_NAME="/vmnt/${DEV_LETTERS}b"

    echo "Picked flavor $KVM_FLAVOR, device $DEV_NAME, image $IMAGE"
    echo $USER1_PARAM
    echo $USER2_PARAM
 

    echo " ============================================================== "
    echo " =============== Starting Tests 53-65  ======================== "
    echo " ============================================================== "

    # Delete keypairs for tests_53_to_65 here
    nova $USER1_PARAM keypair-delete $KEY_PAIR
    rm -f $KEY_FILE
    rm -f "$KEY_FILE.pub"


########################################################################################################
########################################################################################################
########################################################################################################

# 53 nova user: create a volume 
# : nova volume-create --display_name <volume_name> <size_in_GB>, Check with nova volume-list


    STATUS=""
    nova_createVolume STATUS "$USER1_PARAM" "${VOL_GOOD_NAME}" "${VOL_SIZE}"
    if [ "$STATUS" == "available" ];
    then
	msg="PASSED Test 53: volume creation. Got status $STATUS"
    else
	msg="FAILED Test 53: volume creation. Got status $STATUS"
    fi 
    echo "${msg}"
    write_log "${msg}" "${log}"


########################################################################################################
# 54 nova user attach a volume and add contents 
# : nova volume-attach <instance_id> <volume_id> <device>, Check with nova volume-list, 
# for kvm - make a linux-type partition and format it with ext3 fs.  
# http://docs.openstack.org/trunk/openstack-compute/admin/content/managing-volumes.html, 
# for lxc- volume auto-mounted at /vmnt

    makeAddKey $KEY_PAIR $KEY_FILE "$USER1_PARAM"
    nova_bootInstance "$USER1_PARAM" "${INST_KVM_NAME}" "${KVM_FLAVOR}" "${IMAGE}" "--key-name ${KEY_PAIR}"
    KVM_IP=`nova $USER1_PARAM list | grep $INST_KVM_NAME | awk '{ print \$8 }' | sed 's/.*=//'`
    
    echo "Got IP for KVM $KVM_IP"
    # Wait until the network is up in the guest
    echo "Waiting for the guest to boot"
    sleep ${TIMEOUT}

    echo "Looking for $DEV_NAME before attaching. It should not be there"
    sendSshAndGet STATUS "$KEY_FILE" "$KVM_IP" "ls $DEV_NAME" "${USER}"
    
    nova_volumeStatus STATUS "${VOL_GOOD_NAME}" "$USER1_PARAM"
    echo "Status of freshly created volume: $STATUS"
    nova_attachVolume "$USER1_PARAM" "${INST_KVM_NAME}" "${VOL_GOOD_NAME}" "${DEV_NAME}"
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    echo "Status of volume after attaching: $STATUS"

    local EXTRA_FLAGS=""    
    if [ "${HYPERVISOR}" == "lxc" ]
    then
      EXTRA_FLAGS=" -F -F "
    fi

    # With variables set, both kvm and lxc should work the same

    ## make ext3 fs partition and format it
    sendSshAndGet STATUS "${KEY_FILE}" "${KVM_IP}" "ls $DEV_NAME" "${USER}"
    echo "Looking for $DEV_NAME after attaching: $STATUS" 
    
    if [ "$STATUS" == "$DEV_NAME" ]
    then
	if [ "$HYPERVISOR" == "kvm" ]
	then
	    sendSshAndGet STATUS $KEY_FILE $KVM_IP "mkfs -t ext3 $DEV_NAME" "${USER}"
	    sendSshAndGet STATUS $KEY_FILE $KVM_IP "mount $DEV_NAME /mnt" "${USER}"
	    sendSshAndGet STATUS $KEY_FILE $KVM_IP "echo Hello > /mnt/Hello.txt" "${USER}"
	    sendSshAndGet STATUS $KEY_FILE $KVM_IP "cat /mnt/Hello.txt" "${USER}"
	else
	    sendSshAndGet STATUS $KEY_FILE $KVM_IP "sudo /sbin/mkfs.ext3 $DEV_NAME" "${USER}"
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "sudo /bin/mount $DEV_NAME $VMNT_NAME" "${USER}"
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "echo Hello > $VMNT_NAME/Hello.txt" "${USER}"
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "cat $VMNT_NAME/Hello.txt" "${USER}"
	fi

       if [ "$STATUS" == "Hello" ];
       then
           msg="=== PASSED Test 54: Format, write and read back"
       else
           msg="=== FAILED Test 54: Read back $STATUS" 
       fi

       echo "${msg}"
       write_log "${msg}" "${log}"

       if [ "$HYPERVISOR" == "kvm" ]
       then
	   sendSshAndGet STATUS $KEY_FILE $KVM_IP "umount /mnt" "${USER}"
       else
	   sendSshAndGet STATUS $KEY_FILE $KVM_IP "umount ${VMNT_NAME}" "${USER}"
       fi

    else
       msg="=== FAILED Test 54: Device $DEV_NAME is not present in the guest: $STATUS"
    fi

    echo "${msg}"
    write_log "${msg}" "${log}"


    # Undo volume attach. Also works as test 60
    # 60 nova user: detach a volume 
    # : nova volume-detach <instance_id> <volume_id>, Check with nova volume-list
    nova_detachVolume "$USER1_PARAM" "${INST_KVM_NAME}" "${VOL_GOOD_NAME}"
    nova_volumeStatus STATUS "${VOL_GOOD_NAME}" "$USER1_PARAM"
    if [ "$STATUS" != "available" ];
    then
	msg="FAILED test 60: Volume status $STATUS"
    else
	msg="PASSED test 60: After detachment volume status is $STATUS"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    ########################################################################################################
    # 55 nova user: attach a volume to an unauthorized instance 
    # : tried to attach a volume to an instance created by a different user in a different tenant - failed

    nova_bootInstance "$USER2_PARAM" "${INST_BAD_NAME}" "${KVM_FLAVOR}" "${IMAGE}" ""
    
    echo "Errors are okay: this is a denial test"
    nova_attachVolume "$USER1_PARAM" "${INST_BAD_NAME}" "${VOL_GOOD_NAME}" "${DEV_NAME}"
    nova_attachedTo STATUS "${VOL_GOOD_NAME}" "$USER1_PARAM"
    if [ "$STATUS" == "$INST_BAD_NAME" ];
    then
	msg="FAILED: Volume actually attached (test55): $STATUS"
    else
	msg="PASSED test 55: attachment to unauthorized instance failed: $STATUS"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    # Clean up: kill the instance
    echo "Deleting instance $INST_BAD_NAME"
    nova $USER2_PARAM delete $INST_BAD_NAME     

    # Now have good volume detached and available, kvm instance running.
    #
    ########################################################################################################
    # 56 nova user: attach an unauthorized volume to an instance 
    # : tried to attach a volume created by other user in other tenant - failed

    nova_createVolume STATUS "$USER2_PARAM" "${VOL_BAD_NAME}" "${VOL_SIZE}"
    if [ "$STATUS" != "available" ];
    then
	msg="Failed to create valume for test 56: got status $STATUS"
	echo "${msg}"
        exit 1
    fi 
    
    echo "Errors are okay: this is a denial test"
    nova_attachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_BAD_NAME $DEV_NAME
    nova_attachedTo STATUS $VOL_BAD_NAME "$USER2_PARAM"
    if [ "$STATUS" == "$INST_KVM_NAME" ];
    then
	msg="FAILED: Volume actually attached (test56): $STATUS"
    else
	msg="PASSED test 56: attachment of unauthorized volume failed: $STATUS"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    # Clean up: kill the volume, also test 64
    # 64 nova user: delete a volume : nova volume-delete <volume-id>, Check with nova volume-list
    nova $USER2_PARAM volume-delete $VOL_BAD_NAME
    sleep 20
    STATUS=`nova $USER2_PARAM volume-list | grep $VOL_BAD_NAME`
    if [ "$STATUS" == "" ];
    then
	msg="PASSED Test 64: volume deletion"
    else
	msg="FAILED Test 64: volume delete: $STATUS"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"


    ########################################################################################################
    # 57 nova user: attach an existing volume and verify contents 
    # 58 nova user: attach an existing volume and verify contents 

    nova_attachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_GOOD_NAME $DEV_NAME
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    
    if [ "$STATUS" == "in-use" ];
    then
	echo "Volume reattach (test57 kvm) succeeded"
        ## Check contents
        NEW_DEV=""
        #sendSshAndGet NEW_DEV $KEY_FILE $KVM_IP "ls /dev/${DEV_LETTERS}? | grep -v ${DEV_LETTERS}a"
        echo "Found reattached volume as $NEW_DEV"

	if [ "$HYPERVISOR" == "kvm" ]
	then
	    sendSshAndGet NEW_DEV $KEY_FILE $KVM_IP "ls /dev/${DEV_LETTERS}? | grep -v ${DEV_LETTERS}a" "${USER}"
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "mount $NEW_DEV /mnt" "${USER}"
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "cat /mnt/Hello.txt" "${USER}"
	else
	    NEW_DEV=$DEV_NAME
	    sendSshAndGet STATUS $KEY_FILE $KVM_IP "sudo /bin/mount $NEW_DEV $VMNT_NAME" "${USER}"
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "cat $VMNT_NAME/Hello.txt" "${USER}"
	fi

        if [ "$STATUS" == "Hello" ];
        then
            msg="=== PASSED Test 57: Read content from reattached volume"
        else
            msg="=== FAILED Test 57: Reading reattached volume: $STATUS"
        fi
	write_log "${msg}" "${log}"

	if [ "$HYPERVISOR" == "kvm" ]
	then
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "umount /mnt" "${USER}"
	else
            sendSshAndGet STATUS $KEY_FILE $KVM_IP "sudo /bin/umount ${VMNT_NAME}" "${USER}"
	fi

    else
	msg="=== FAIL Test 57: Volume reattach status is $STATUS"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"
    
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
	msg="PASSED test 62/63 (unauthorized volume detach): Volume still attached"
    else
	msg="FAILED test 62/63 (unauthorized volume detach): After detachment volume is $STATUS"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    ########################################################################################################
    # 65 nova user: delete an unauthorized volume : operation failed 

    # User 2 does delete, user 1 (owner) checks
    echo "Errors are okay: this is a denial test"
    nova $USER2_PARAM volume-delete $VOL_GOOD_NAME
    nova_volumeStatus STATUS $VOL_GOOD_NAME "$USER1_PARAM"
    if [ "$STATUS" != "" ];
    then
	msg="PASSED test 65 (unauthorized volume delete): Volume still there $STATUS"
    else
	msg="FAILED test 65 (unauthorized volume delete): Volume is gone"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    # Clean up
    nova_detachVolume "$USER1_PARAM" $INST_KVM_NAME $VOL_GOOD_NAME
    delete_all_volumes # no openrc file here?

    nova $USER1_PARAM keypair-delete $KEY_PAIR
    rm -f $KEY_FILE
    rm -f "$KEY_FILE.pub"

}