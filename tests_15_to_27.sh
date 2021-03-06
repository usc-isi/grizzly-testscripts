#!/bin/bash

source functions.sh
source volume.sh
source glance.sh

function tests_15_to_27() {

    local log=$1
    local openrc_path=$2
    local LIBVIRT_TYPE=$3
    local FLAVOR=$4
    local USER=$5
    local TIMEOUT=$6
    local SLEEP=$7
    local msg
    
    TENANT1=demo1
    TENANT2=demo2
    INST_CNT=3
    
    declare INST_IP
    declare INST_ID
    declare KEY_NAME
    declare KEY
    declare KEY_EXIST
    declare VOLUME
    declare USER
    
    declare OTHER_INST_IP
    declare OTHER_INST_ID
    declare OTHER_KEY_NAME
    declare OTHER_VOLUME
    declare DEV_NAME=""
    declare DEV_LETTERS=""
    declare VMNT_NAME=""
    
    declare FILE=hello.txt
    declare CONTENTS="hello from Malek"
    declare testNum=0
    declare i=0
    declare j=0

    declare -a TENANT=("${TENANT1}" "${TENANT2}")


    echo " ============================================================== "
    echo " ================ Starting Tests 15-27 ======================== "
    echo " ============================================================== "

    # try to delete file in case it exists from previous failed regression run
    if [ -e "${FILE}" ]
    then
	echo "Old file ${FILE} exists, possibly from previous run --> deleting"
	rm -rf ${FILE}
    fi
	
    for j in $TENANT; do
	
	echo " "
	echo "[$LIBVIRT_TYPE] $j TESTING ============================================================="
	
        openrc="${openrc_path}openrc-$j"
	echo "Sourcing openrc file: ${openrc} for TENANT: $j"
        source ${openrc}
	
	if [ "$LIBVIRT_TYPE" = "kvm" ]; then
	    # exclude string with 'lxc'
	    IMG_NAME=`euca-describe-images | grep -nr "fs" | grep "demo" | grep -v "lxc" | grep ami | awk '{ print $2}' | head -n 1`
	    #IMG_NAME=`euca-describe-images | grep fs | awk '{ print $2}'`
	    DEV_LETTERS="vd"
	elif [ "$LIBVIRT_TYPE" = "lxc" ]; then
	    IMG_NAME=`euca-describe-images | grep $j | grep lxc_fs | grep ami | awk '{ print $2 }' | head -n 1`
	    DEV_LETTERS="sd"
	    # for LXC, create many loopback devices to avoid error: 'These required options are missing: device
	    echo "Creating Loopback Devices for LXC"
	else
	    echo "ERROR: Unknown LIBVIRT_TYPE: ${LIBVIRT_TYPE}"
	fi
	DEV_NAME="/dev/${DEV_LETTERS}b"
	VMNT_NAME="/vmnt/${DEV_LETTERS}b"

	if [ "$IMG_NAME" ]; then
	    
	    KEY_NAME=eucakeypair-$j
	    KEY=$KEY_NAME.pem
	    KEY_EXIST=`euca-describe-keypairs | grep $KEY_NAME | awk '{ print $2 }'`
	    if [ "$KEY_EXIST" != "$KEY_NAME" ]; then
		euca-add-keypair $KEY_NAME > ${openrc_path}$KEY
		chmod 600 ${openrc_path}$KEY
	    fi
	    
	    echo " "
	    echo "---------------------------------------------------------------------------"
	    echo " 7. euca-run-instances -k $KEY_NAME -t $FLAVOR $IMG_NAME"
	    echo "---------------------------------------------------------------------------"
	    RET=`euca-run-instances -k $KEY_NAME -t $FLAVOR $IMG_NAME`
	    echo " Please wait until one instance is running"
	    sleep ${SLEEP}
	    for k in `seq 1 $TIMEOUT`; do
		INST_ID=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print $2 }'`
                if [ "${LIBVIRT_TYPE}" = "kvm" ]
                    then
                    INST_IP=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print$15 }' | head -n 1`
                else
                    INST_IP=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print$14 }' | head -n 1`
		fi

		if [ -z $INST_IP ]; then
		    msg=" =====> Step#7. is not running yet: $INST_ID $INST_IP"
		    echo "${msg}"
                    #write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#7. is successfully DONE: "
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    echo "INST_ID:$INST_ID"
		    echo "INST_IP: $INST_IP"
		    echo " "
		    break
		fi
	    done
	    echo " "
	    euca-describe-instances | grep $KEY_NAME | grep $INST_ID
	    
	    if [ $j == $TENANT1 ]; then
		OTHER_INST_IP=$INST_IP
		OTHER_IMG_NAME=$IMG_NAME
		OTHER_INST_ID=$INST_ID
		OTHER_KEY_NAME=$KEY_NAME
	    fi
	    
	    testNum=15
	    msg="euca-create-volume -s 1 -z nova"
	    print_test_msg "${testNum}" "${msg}" 
	    RET=`euca-create-volume -s 1 -z nova`
	    sleep ${SLEEP}
		
	    msg="Checking to make sure created volumes are available"
	    command="euca-describe-volumes"
	    print_test_command_msg "${testNum}" "${msg}" "${command}"	    
	    RET=`euca-describe-volumes`
	    status=`echo $RET | awk '{ print $5}'`
	    volume=`echo $RET | awk '{ print $2}'`
	    
	    if [ "${status}" != "available" ]
		then
		echo "VOLUME: ${volume} not in available state: ${status}"
		msg=" =====> Step#15. Failed"
                echo "${msg}"
                write_log "${msg}" "${log}"
		exit 1
	    else
		msg=" =====> Step#15. is successfully DONE."
                echo "${msg}"
                write_log "${msg}" "${log}"
	    fi
	    
	    if [ $j == $TENANT1 ]; then
		VOLUME=$volume
		OTHER_VOLUME=$VOLUME
	    fi
	    
	    testNum=16
	    msg="euca-attach-volume ${volume} -i ${INST_ID} -d ${DEV_NAME}"
	    print_test_msg "${testNum}" "${msg}"
	    RET=`euca-attach-volume ${volume} -i ${INST_ID} -d ${DEV_NAME}`
	    sleep ${SLEEP}

	    msg="Checking to make sure created volumes are attached"
	    command=" euca-describe-volumes"
	    print_test_command_msg "${testNum}" "${msg}" "${command}"
	    attached=$(volume_attached "${volume}")
	    status=$(volume_status "${volume}")
	    state=$(volume_state "${volume}")
	    
	    if [ "${attached}" != "true" ]
	    then
		echo "VOLUME: ${volume} not Attached -- Status: ${status} | State: ${state}"
		msg=" =====> Step#16. Failed"
		echo "${msg}"
                write_log "${msg}" "${log}"
		exit 1
	    else
	       	    

                # With variables set, both kvm and lxc should work the same
                ## make ext3 fs partition and format it                                                           
		echo "VOLUME: ${volume} attached, now ssh to add contents..."
		echo " Step8. ssh -i ${openrc_path}$KEY $USER@$INST_IP"
		sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "ls $DEV_NAME" "${USER}"
		echo "Looking for $DEV_NAME after attaching: $STATUS"
		
		if [ "$STATUS" == "$DEV_NAME" ];
		then
		    if [ "$LIBVIRT_TYPE" == "kvm" ]
		    then
			sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "mkfs -t ext3 $DEV_NAME" "${USER}"
			sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "mount $DEV_NAME /mnt" "${USER}"
			sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "echo Hello > /mnt/Hello.txt" "${USER}"
			sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "cat /mnt/Hello.txt" "${USER}"
		    else
			sendSshAndGet STATUS "${openrc_path}$KEY" "sudo /sbin/mkfs.ext3 $DEV_NAME" "${USER}"
			sendSshAndGet STATUS "${openrc_path}$KEY" "sudo /bin/mount $DEV_NAME $VMNT_NAME" "${USER}"
			sendSshAndGet STATUS "${openrc_path}$KEY" "echo Hello > $VMNT_NAME/Hello.txt" "${USER}"
			sendSshAndGet STATUS "${openrc_path}$KEY" "cat $VMNT_NAME/Hello.txt" "${USER}"
		    fi

		    if [ "$STATUS" == "Hello" ];
		    then
			msg="=== PASSED Step#${testNum}: Format, write and read back"
		    else
			msg="=== FAILED Step#${testNum}: Read back $STATUS"
		    fi
		    echo "${msg}"
		    write_log "${msg}" "${log}"

		    if [ "$LIBVIRT_TYPE" == "kvm" ]
		    then
			sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "umount /mnt" "${USER}"
		    else
			sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "sudo /bin/umount ${VMNT_NAME}" "${USER}"
		    fi

		else
		    msg="=== FAILED Step#${testNum}: Device $DEV_NAME is not present in the guest: $STATUS"
		fi
		
		echo "${msg}"
		write_log "${msg}" "${log}"
	    fi

            # Now detach volume new file was added to, and then re-attach and verify file exists
#	    source ./openrc-$j
	    source ${openrc}
	    testNum=19
	    msg="Detach and re-attach volume with added contents to verify contents persistent"
	    print_test_msg "${testNum}" "${msg}"
	    $(detach_volume "${volume}")
	    sleep ${TIMEOUT}
	    
	    attached=$(volume_attached "${volume}")
	    status=$(volume_status "${volume}")
	    state=$(volume_state "${volume}")
	    
	    if [ "${status}" != "available" ]
	    then
		echo "VOLUME: ${volume} not Dettached: ${status}"
		exit 1
	    else
		msg=" =====> Step#22. successfully Completed -- VOLUME: ${volume} successfully Detached"
		echo "${msg}"
                write_log "${msg}" "${log}"
	    fi
	    
	    RET=`euca-attach-volume ${volume} -i ${INST_ID} -d ${DEV_NAME}`
	    sleep ${TIMEOUT}
	    attached=$(volume_attached "${volume}")
	    status=$(volume_status "${volume}")
	    state=$(volume_state "${volume}")
	    if [ "${attached}" == "true" ]
	    then
		echo "Verifying if File: $FILE Exists"
	    
		NEW_DEV=""
		if [ "$LIBVIRT_TYPE" == "kvm" ]
		then
		    sendSshAndGet NEW_DEV "${openrc_path}$KEY" "${INST_IP}" "ls /dev/${DEV_LETTERS}? | grep -v ${DEV_LETTERS}a" "${USER}"
		    echo "Found reattached volume as $NEW_DEV"
		    sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "mount $NEW_DEV /mnt" "${USER}"
		    sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "cat /mnt/Hello.txt" "${USER}"
		else
		    NEW_DEV=$DEV_NAME
		    sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "sudo /bin/mount $NEW_DEV $VMNT_NAME" "${USER}"
		    sendSshAndGet STATUS "${openrc_path}$KEY" "${INST_IP}" "cat $VMNT_NAME/Hello.txt" "${USER}"
		fi

		if [ "$STATUS" == "Hello" ];
		then
		    msg="=== PASSED Test 19: Read content from reattached volume"
		else
		    msg="=== FAILED Test 19: Reading reattached volume: $STATUS"
		fi
		echo "${msg}"
		write_log "${msg}" "${log}"
	    else
		msg="Re-attachment of content verification volume failed"
		echo "${msg}"
		write_log "${msg}" "${log}"
	    fi

	    if [ $j == $TENANT2 ]; then
		testNum=17
		msg="Attach a volume to an unauthorized instance"
		print_test_msg "${testNum}" "${msg}"
		
	            # First detach if volume is attached
		attached=$(volume_attached "${volume}")
		if [ "${attached}" == "true" ]
		then
		    echo "${volume} currently attached, detaching ..."
		    $(detach_volume "${volume}")
		fi
		
		
		if [ "$LIBVIRT_TYPE" == "kvm" ]
		then
		    echo " euca-attach-volume ${volume} -i ${OTHER_INST_ID} -d /dev/vdc"
		    echo "---------------------------------------------------------------------------"
		    RET=`euca-attach-volume ${volume} -i ${OTHER_INST_ID} -d /dev/vdc`
		else
                    echo " euca-attach-volume ${volume} -i ${OTHER_INST_ID} -d /dev/sdc"
                    echo "---------------------------------------------------------------------------"
                    RET=`euca-attach-volume ${volume} -i ${OTHER_INST_ID} -d /dev/sdc`
		fi
		sleep ${TIMEOUT}
		
		msg="Checking to make sure volume not attached to unauthorized instance"
		command=" euca-describe-volumes"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		attached=$(volume_attached "${volume}")
		status=$(volume_status "${volume}")
		state=$(volume_state "${volume}")
		displayName=`echo $RET | awk '{ print $3}'`
		
		if [ "${attached}" != "true" ]
		then
		    echo "VOLUME: ${volume} not Attached to Unauthorized Instance: ${OTHER_INST_ID} -- Status: ${status} | State: ${state}"
		    msg=" =====> Step#17. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#17. Failed: Volume: ${volume} was attached to Unauthorized instance: ${OTHER_INST_ID}."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    exit 1
		fi
		
		testNum=18
		msg="Attach an unauthorized volume to an instance"
		command="euca-attach-volume ${OTHER_VOLUME} -i ${INST_ID} -d /dev/vdc"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		RET=`euca-attach-volume ${OTHER_VOLUME} -i ${INST_ID} -d /dev/vdc`
		sleep ${TIMEOUT}
		
		msg=" Checking to make sure unauthorized volume not attached to instance"
		command=" euca-describe-volumes"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		attached=$(volume_attached "${volume}")
		status=$(volume_status "${volume}")
		state=$(volume_state "${volume}")
		
		if [ "${attached}" != "true" ]
		then
		    echo "VOLUME: ${OTHER_VOLUME} not Attached to Unauthorized Instance: ${INST_ID} -- Status: ${status} | State: ${state}"
		    msg=" =====> Step#18. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#18. Failed: Volume: ${OTHER_VOLUME} was attached to Unauthorized instance: ${INST_ID}."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    exit 1
		fi
	    fi
	    
	    if [ $j == $TENANT2 ]; then
		testNum=22
		msg="euca-detach-volume ${volume} "
		print_test_msg "${testNum}" "${msg}"
		RET=`euca-detach-volume ${volume}`
		sleep ${SLEEP}    
		    
		msg=" Checking to make sure attached volumes are de-attached"
		command=" euca-describe-volumes"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		available=$(volume_attached "${volume}")
		status=$(volume_status "${volume}")
		state=$(volume_state "${volume}")
		if [ "${available}" == "true" ]
		then
		    echo "VOLUME: ${volume} not Dettached: ${status}"
		    msg=" =====> Step#22. Failed"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    exit 1
		else
		    msg=" =====> Step#22. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		fi
		
		testNum=23
		msg=" Testing reattachment"
		command="euca-attach-volume ${volume} "
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		RET=`euca-attach-volume ${volume} -i ${INST_ID} -d /dev/vdc`
		sleep ${TIMEOUT}
		
		msg=" Checking to make sure attached volumes are attached"
		command=" euca-describe-volumes"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		RET=`euca-describe-volumes`
		status=`echo $RET | awk '{ print $11}'`
		volume=`echo $RET | awk '{ print $2}'`
		user=`echo $RET | awk '{ print $4}'`
		state=`echo $RET | awk '{ print $5}'`
		
		if [ "${status}" != "attached" ] || [ "${state}" != "in-use" ]
		then
		    echo "VOLUME: ${volume} not re-attached: ${status}"
		    msg=" =====> Step#23. Failed"
		    echo "${msg}"
		    write_log "${msg}" "${log}"
		    exit 1
		else
		    msg=" =====> Step#23. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		fi
		
		echo " "
		echo "---------------------------------------------------------------------------"
		echo " User detach an unauthorized volume from an instance"
		echo " User $j has Volume Attached, switch to $TENANT1 and attempt to detach"
		echo " 24. euca-detach-volume ${volume}"
		echo "---------------------------------------------------------------------------"
		source ./openrc-$TENANT1
		RET=`euca-detach-volume ${volume}`
		sleep ${SLEEP}
		
		msg=" Checking to make sure volume was not attached"
		command=" euca-describe-volumes"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		
		available=$(volume_attached "${volume}")
		status=$(volume_status "${volume}")
		state=$(volume_state "${volume}")
		if [ "${available}" != "true" ]
		then
		    echo "VOLUME: ${volume} not ttached: ${status}"
		    msg=" =====> Step#24. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#24. Failed. Status: ${status} | State: ${state}"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    exit 1
		fi
		
		testNum=25
		msg=" detach volume from an unauthorized instance \n Try to detach ${TENANT1} VOLUME: ${OTHER_VOLUME} from Instance: ${OTHER_INST}"
		command="euca-detach-volume ${OTHER_VOLUME}"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		RET=`euca-detach-volume ${OTHER_VOLUME}`
		
		msg="Checking to make sure volume: ${OTHER_VOLUME} was not de-attached"
		command="euca-describe-volumes"
		print_test_command_msg "${testNum}" "${msg}" "${command}"
		
		available=$(volume_attached "${volume}")
		status=$(volume_status "${volume}")
		state=$(volume_state "${volume}")
		if [ "${available}" != "true" ]
		then
		    echo "VOLUME: ${OTHER_VOLUME} was not Dettached -- Status: ${status} | State: ${state}"
		    msg=" =====> Step#25. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#25. Failed. VOLUME: ${OTHER_VOLUME} was detached -- Status: ${status} | State: ${state}"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    exit 1
		fi
		
	        # Switch back to correct user
		echo "Sourcing Correct User's credentials again: $j"
		echo " Resourcing correct user: $j credentials file: ${openrc}"
		source ${openrc}
		
		echo " "
		echo "---------------------------------------------------------------------------"
		echo " 26. euca-delete-volume ${volume}"
		echo "---------------------------------------------------------------------------"
		RET=`euca-delete-volume ${volume}`
		sleep ${SLEEP}
		status=`echo $RET | awk '{ print $5}'`
		volume=`echo $RET | awk '{ print $2}'`
		displayName=`echo $RET | awk '{ print $3}'`
		
		if [ "${status}" != "deleting" ] && [ "${status}" != "" ]
		then
		    echo "VOLUME: ${volume} not Deleted: ${status}"
		    msg=" =====> Step#26. Failed"
		    echo "${msg}"
		    write_log "${msg}" "${log}"
		    exit 1
		else
		    msg=" =====> Step#26. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		fi
	    fi
	    
	    
	    if [ $j == $TENANT2 ]
	    then
		echo " "
		echo "---------------------------------------------------------------------------"
		echo "Delete an un-authorized Volume"
		echo " 27. euca-delete-volume ${OTHER_VOLUME}"
		echo "---------------------------------------------------------------------------"
		RET=`euca-delete-volume ${OTHER_VOLUME}`
		TEST_OUT=`euca-delete-volume ${OTHER_VOLUME} 2>&1`
		sleep ${SLEEP}
		status=`echo $RET | awk '{ print $5}'`
		volume=`echo $RET | awk '{ print $2}'`
		sleep ${SLEEP}
		echo "RET: ${RET}"
		echo "TEST_OUT: ${TEST_OUT}"
		#if [ "${status}" != "deleting" ] && [ "${status}" != "" ]
		if [[ "$TEST_OUT" == *VolumeNotFound* ]]
		then
		    echo "Unauthorized VOLUME: ${volume} not Deleted: ${status}"
		    msg=" =====> Step#27. is successfully DONE."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#27. Failed."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    exit 1
		fi
	    fi
	fi
    done
    
    for j in $TENANT; do
	
	echo " "
	echo "---------------------------------------------------------------------------"
	echo "*. cleaning work"
	echo "---------------------------------------------------------------------------"
	euca-delete-keypair $KEY_NAME
	echo " KEY DELETED "
	echo "Remaining key and instance of $TENANT1 is DELETED: "
	source "${openrc_path}openrc-$TENANT1"
	euca-terminate-instances $OTHER_INST_ID
	euca-delete-keypair $OTHER_KEY_NAME
	echo " KEY DELETED "
    done
}