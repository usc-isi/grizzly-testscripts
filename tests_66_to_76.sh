#!/bin/bash

source functions.sh
source volume.sh
source glance.sh

function tests_66_to_76() {

    local log=$1
    local openrc_user1=$2
    local openrc_user2=$3
    local msg

    local timeoutWait=60
    local name=cirros-0.3.1
    local image=cirros-0.3.1-x86_64-disk.img
    local image_url=http://download.cirros-cloud.net/0.3.1/$image
    local imageUploaded=false
    
    source ${openrc_user1}
    nova keypair-delete key70;                                                                                         
    /bin/rm key70.pem;                                                                          

    echo " ============================================================== "
    echo " ================ Starting Tests 66-76 ======================== "
    echo " ============================================================== "

    testNum=66
    print_test_msg "${testNum}" "user: upload a new public image"
    
    glance image-create --name=$name --is-public=true --container-format=bare --disk-format=qcow2 < $image
    
    if [ "`glance image-show $name | grep is_public | grep True`" == "" ]; then
	msg="Step#${testNum} Failed to create public image $name"
    else
	msg="Step#${testNum} Successfully DONE"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"


    testNum=67
    print_test_msg "${testNum}" "user: upload a new private image"

    privateName=private-$name
    glance image-create --name=$privateName --is-public=false --container-format=bare --disk-format=qcow2 < $image
    
    if [ "`glance image-show $privateName | grep is_public | grep False`" == "" ]; then
	msg="Step#${testNum} Failed to create public image $name"
    else
	msg="Step#$testNum successfully DONE"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    
    testNum=68
    print_test_msg "${testNum}" "user: create a new image from a running instance(snapshot)"

    instanceName=test$testNum
    snapshot=snapshot-$instanceName
    snapshotOk=
    if [ -n "$(nova image-list | grep " $name ")" ]; then
	nova boot --flavor 1 --image $name $instanceName

	timeout_check $timeoutWait "nova list | grep $instanceName | grep ACTIVE"
	if [ $? -eq 0 ]; then
	    nova image-create $instanceName $snapshot
	    timeout_check $timeoutWait "nova image-list | grep $snapshot | grep ACTIVE"
	    if [ $? -eq 0 ]; then
		msg="Step#${testNum} Successfully DONE" 
		snapshotOk=1
	    else
		msg="Step#${testNum} Failed because snapshot $snapshot failed to become active"
	    fi
	    echo "${msg}"
            write_log "${msg}" "${log}"

	    echo nova delete $instanceName
	    nova delete $instanceName
	else
	    msg="Step#${testNum} Failed because instance $instanceName failed to become active"
	    echo "${msg}"
            write_log "${msg}" "${log}"
	fi
    else
	msg="Step#${testNum} Failed because image $name missing"
	echo "${msg}"
        write_log "${msg}" "${log}"
    fi

    testNum=69
    print_test_msg "${testNum}" "user: create a new image from an unauthorized running instance"

    source ${openrc_user2}
    nova image-create $instanceName $snapshot
    if [ $? -ne 0 ]; then
	msg="Step#${testNum} Successfully DONE"
    else
	msg="Step#${testNum} Failed because should not be able to snapshot"
    fi

    echo "${msg}"
    write_log "${msg}" "${log}"

    source ${openrc_user1}
    testNum=70
    print_test_msg "${testNum}" "user: launch an instance using snapshot image"

    instanceName=instance$testNum
    keyName=key$testNum
    snapshotInstanceOk=
    if [ $snapshotOk ]; then
	nova keypair-add $keyName > ${keyName}.pem
	chmod 600 ${keyName}.pem
	nova boot --flavor 1 --image $snapshot --key-name $keyName $instanceName
	timeout_check $timeoutWait "nova list | grep $instanceName | grep ACTIVE"
	if [ $? -eq 0 ]; then
	    msg="Step#${testNum} Successfully DONE"
	    snapshotInstanceOk=1
	else
	    msg="Step#${testNum} Failed because instance $instanceName failed to become active"
	fi
	echo "${msg}"
        write_log "${msg}" "${log}"
    else
	msg="Step#${testNum} Failed because snapshot $snapshot failed to become active"
	echo "${msg}"
        write_log "${msg}" "${log}"
    fi
    
    testNum=71
    msg="user: launch an instance using snapshot image"
    print_test_msg "${testNum}" "${msg}"

    if [ $snapshotInstanceOk ]; then
	ip=$(nova list | grep $instanceName | get_field -1 | sed 's/net=//')
	timeout_check $timeoutWait "ssh -o StrictHostKeyChecking=no -i ${keyName}.pem cirros@$ip env | grep HOME | grep cirros"
	if [ $? -eq 0 ]; then
	    msg="Step#${testNum} Successfully DONE"
	else
	    msg="Step#${testNum} Failed to ssh into instance at $ip"
	fi
	echo "${msg}"
        write_log "${msg}" "${log}"
    fi

    testNum=72
    msg="user: make a private image public" 
    print_test_msg "${testNum}" "user: make a private image public"
    
    if [ "`glance image-show $privateName | grep is_public | grep -i false`" ]; then 
	if [ "`glance image-update $privateName --is-public True | grep is_public | grep -i true`" ]; then
	    msg="Step#${testNum} Successfully DONE"
	else
	    msg="Failed to change image is_public status"
	fi
	echo "${msg}"
        write_log "${msg}" "${log}"
    else
	msg="Step#${testNum} Failed because image is already public"
	echo "${msg}"
        write_log "${msg}" "${log}"
    fi
    
    testNum=73
    print_test_msg "${testNum}" "user: make a public image private"

    if [ "`glance image-show $privateName | grep is_public | grep -i true`" ]; then 
	if [ "`glance image-update $privateName --is-public False | grep is_public | grep -i false`" ]; then
	    msg="Step#${testNum} Successfully DONE"
	else
	    msg="Step#$testNum Failed to change image is_public status"
	fi
	echo "${msg}"
        write_log "${msg}" "${log}"
    else
	msg="Step#${testNum} Failed because image is already private"
	echo "${msg}"
        write_log "${msg}" "${log}"
    fi
    
    testNum=74
    print_test_msg "${testNum}" "user: make a public image to private image owned by another user (should fail)"

    source ${openrc_user2}
    if [ "`glance image-show $name | grep is_public | grep -i true`" ]; then 
	if [ "`glance image-update $name --is-public False | grep is_public | grep -i false`" ]; then
	    msg="Step#${testNum} Failed to change image is_public status"
	else
	    msg="Step#${testNum} Successfully DONE"
	fi
	echo "${msg}"
        write_log "${msg}" "${log}"
    else
	msg="Step#${testNum} Failed because image is already private"
	echo "${msg}"
        write_log "${msg}" "${log}"
    fi

    testNum=75
    print_test_msg "${testNum}""user: delete an image"

    source ${openrc_user1}
    echo glance image-delete $privateName
    glance image-delete $privateName
    if [[ $? -eq 0 && -z "`glance index | grep $privateName`" ]]; then
	msg="Step#${testNum} Successfully DONE"
    else
	msg="Step#${testNum} Failed to delete image $privateName"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    testNum=76
    print_test_msg "${testNum}" "user: delete an unauthorized image"

    source ${openrc_user2}
    if [ -n "`glance image-delete $name 2>&1 | grep Forbidden`" ]; then
	msg="Step#${testNum} Successfully DONE"
    else
	msg="Step#${testNum} Failed, should not be able to delete $image"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

    # clean up
    source ${openrc_user1}
    nova keypair-delete key70
    /bin/rm key70.pem

}