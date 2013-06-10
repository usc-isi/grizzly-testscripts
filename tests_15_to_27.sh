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
    local msg
    
    TENANT1=demo1
    TENANT2=demo2
    INST_CNT=3
    
    declare INST_IP
    declare INST_ID
    declare KEYNAME
    declare KEY
    declare KEY_EXIST
    declare VOLUME
    declare USER
    
    declare OTHER_INST_IP
    declare OTHER_INST_ID
    declare OTHER_KEYNAME
    declare OTHER_VOLUME
    
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
	    IMG_NAME=`euca-describe-images | grep -nr "fs" | grep "demo" | grep -v "lxc" | awk '{ print $2}'`
	    #IMG_NAME=`euca-describe-images | grep fs | awk '{ print $2}'`
	elif [ "$LIBVIRT_TYPE" = "lxc" ]; then
	    IMG_NAME=`euca-describe-images | grep $j | grep lxc_fs | grep ami | awk '{ print $2 }'`
	else
	    echo "ERROR: Unknown LIBVIRT_TYPE: ${LIBVIRT_TYPE}"
	fi
	
	if [ "$IMG_NAME" ]; then
	    
	    KEY_NAME=keypair-$j
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
	    sleep 60
	    for k in `seq 1 $TIMEOUT`; do
		INST_ID=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print $2 }'`
		INST_IP=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print $15 }'` 
		if [ -z $INST_IP ]; then
		    msg=" =====> Step#7. is not running yet: $INST_ID $INST_IP"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
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
	    sleep 30
		
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
	    msg="euca-attach-volume ${volume} -i ${INST_ID} -d /dev/vdb"
	    print_test_msg "${testNum}" "${msg}"
	    RET=`euca-attach-volume ${volume} -i ${INST_ID} -d /dev/vdb`
	    sleep 30
	    

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
		
		echo "VOLUME: ${volume} attached, now ssh to add contents..."
		echo " Step8. ssh -i ${openrc_path}$KEY $USER@$INST_IP"
		COMMAND=`echo "${CONTENTS}" >& $FILE`
		ssh -i ${openrc_path}$KEY $USER@$INST_IP 'echo "Hello from Malek" >& hello.txt; ls; cat hello.txt'
		msg=" =====> Step#16. is successfully DONE."
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
	    sleep 30;
	    
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
	    
	    RET=`euca-attach-volume ${volume} -i ${INST_ID} -d /dev/vdb`
	    sleep 30
	    attached=$(volume_attached "${volume}")
	    status=$(volume_status "${volume}")
	    state=$(volume_state "${volume}")
	    if [ "${attached}" == "true" ]
	    then
		echo "Verifying if File: $FILE Exists"
		ssh -i ${openrc_path}$KEY $USER@$INST_IP '
	  if [ ! -e "hello.txt" ]
	  then
	      msg="Step 19. Failed. FILE DOES NOT EXIST!"
              echo "${msg}"
              write_log "${msg}" "${log}"
	      ls
	      exit
	  else
	      echo "FILE EXISTS";
	      echo "File Contents:";
	      cat hello.txt;
	      msg=echo "Step 19. is successfully DONE."
              echo "${msg}"
              write_log "${msg}" "${log}"
	  fi'
	    else
		echo "Re-attachment of content verification volume failed"
		exit 1
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
		
		echo " euca-attach-volume ${volume} -i ${OTHER_INST_ID} -d /dev/vdc"
		echo "---------------------------------------------------------------------------"
		RET=`euca-attach-volume ${volume} -i ${OTHER_INST_ID} -d /dev/vdc`
		sleep 30
		
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
		sleep 30
		
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
		sleep 30    
		    
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
		sleep 30
		
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
		sleep 30
		
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
		sleep 30
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
		sleep 30
		status=`echo $RET | awk '{ print $5}'`
		volume=`echo $RET | awk '{ print $2}'`
		sleep 30
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