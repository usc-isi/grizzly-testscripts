#!/bin/bash

source functions.sh
source volume.sh


function tests_66_to_76() {

    timeoutWait=60
    name=cirros-0.3.1
    image=cirros-0.3.1-x86_64-disk.img
    image_url=http://download.cirros-cloud.net/0.3.1/$image
    imageUploaded=false

    source openrc-demo1
    
    trap "{                                                                                                           
    source openrc-demo1;                                                                                               
    nova image-delete cirros-0.3.1;                                                                                    
    nova image-delete private-cirros-0.3.1;                                                                            
    nova image-delete snapshot-test68;                                                                                 
    nova delete instance70;                                                                                            
    nova keypair-delete key70;                                                                                         
    /bin/rm key70.pem;                                                                                                 
}" EXIT


    testNum=66
    print_test_msg "${testNum}" "user: upload a new public image"
    
    glance image-create --name=$name --is-public=true --container-format=bare --disk-format=qcow2 < $image
    
    if [ "`glance image-show $name | grep is_public | grep True`" == "" ]; then
	echo XXXX Test$testNum Failed to create public image $name
    else
	echo == Test$testNum OK
    fi


    testNum=67
    print_test_msg "${testNum}" "user: upload a new private image"

    privateName=private-$name
    glance image-create --name=$privateName --is-public=false --container-format=bare --disk-format=qcow2 < $image
    
    if [ "`glance image-show $privateName | grep is_public | grep False`" == "" ]; then
	echo XXXX Test$testNum Failed to create public image $name
    else
	echo == Test$testNum OK
    fi

    
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
		echo == Test$testNum OK
		snapshotOk=1
	    else
		echo XXXX Test$testNum Failed because snapshot $snapshot failed to become active
	    fi
	    echo nova delete $instanceName
	    nova delete $instanceName
	else
	    echo XXXX Test$testNum Failed because instance $instanceName failed to become active
	fi
    else
	echo XXXX Test$testNum Failed because image $name missing
    fi


    testNum=69
    print_test_msg "${testNum}" "user: create a new image from an unauthorized running instance"

    source openrc-demo2
    nova image-create $instanceName $snapshot
    if [ $? -ne 0 ]; then
	echo == Test$testNum OK
    else
	echo XXXX Test$testNum Failed because should not be able to snapshot
    fi
    source openrc-demo1

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
	    echo == Test$testNum OK
	    snapshotInstanceOk=1
	else
	    echo XXXX Test$testNum Failed because instance $instanceName failed to become active
	fi
    else
	echo XXXX Test$testNum Failed because snapshot $snapshot failed to become active
    fi
    
    testNum=71
    echo == Test $testNum user: launch an instance using snapshot image
    print_test_msg "${testNum}" "user: launch an instance using snapshot image"


    if [ $snapshotInstanceOk ]; then
	ip=$(nova list | grep $instanceName | get_field -1 | sed 's/net=//')
	timeout_check $timeoutWait "ssh -o StrictHostKeyChecking=no -i ${keyName}.pem cirros@$ip env | grep HOME | grep cirros"
	if [ $? -eq 0 ]; then
	    echo == Test$testNum OK
	else
	    echo XXXX Test$testNum Failed to ssh into instance at $ip
	fi
    fi

    testNum=72
    echo == Test $testNum user: make a private image public 
    print_test_msg "${testNum}" "user: make a private image public"
    
    if [ "`glance image-show $privateName | grep is_public | grep -i false`" ]; then 
	if [ "`glance image-update $privateName --is-public True | grep is_public | grep -i true`" ]; then
	    echo == Test$testNum OK
	else
	    echo === Failed to change image is_public status
	fi
    else
	echo XXXX Test$testNum Failed because image is already public
    fi
    
    testNum=73
    print_test_msg "${testNum}" "user: make a public image private"

    if [ "`glance image-show $privateName | grep is_public | grep -i true`" ]; then 
	if [ "`glance image-update $privateName --is-public False | grep is_public | grep -i false`" ]; then
	    echo == Test$testNum OK
	else
	    echo XXXX Test$testNum Failed to change image is_public status
	fi
    else
	echo XXXX Test$testNum Failed because image is already private
    fi
    
    testNum=74
    print_test_msg "${testNum}" "user: make a public image to private image owned by another user (should fail)"

    source openrc-demo2
    if [ "`glance image-show $name | grep is_public | grep -i true`" ]; then 
	if [ "`glance image-update $name --is-public False | grep is_public | grep -i false`" ]; then
	    echo XXXX Test$testNum Failed to change image is_public status
	else
	echo == Test$testNum OK
	fi
    else
	echo XXXX Test$testNum Failed because image is already private
    fi

    testNum=75
    print_test_msg "${testNum}""user: delete an image"

    source openrc-demo1
    echo glance image-delete $privateName
    glance image-delete $privateName
    if [[ $? -eq 0 && -z "`glance index | grep $privateName`" ]]; then
	echo == Test$testNum OK
    else
	echo XXXX Test$testNum Failed to delete image $privateName
    fi
    
    testNum=76
    print_test_msg "${testNum}" "user: delete an unauthorized image"

    source openrc-demo2
    if [ -n "`glance image-delete $name 2>&1 | grep Forbidden`" ]; then
	echo == Test$testNum OK
    else
	echo XXXX Test$testNum Failed, should not be able to delete $image
    fi

    # clean up
    source openrc-demo1
    glance image-delete $name
    nova delete $instanceName
    nova keypair-delete key70
    /bin/rm key70.pem

}