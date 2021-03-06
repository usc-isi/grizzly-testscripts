#!/bin/bash

source functions.sh
source volume.sh
source glance.sh

declare LOGFILE

#trap cleanUp EXIT
declare KEYNAME=keypair-demo1
declare KEYNAME_2=keypair-demo2
declare UNAUTHORIZED_IMAGE=demo2_fs
declare IMAGE=kvm_fs
declare OPENRC_DEMO2=/root/jp_scripts/openrc-demo2
declare OPENRC_DEMO1=/root/jp_scripts/openrc-demo1
declare TIMEOUT=600
declare FLAVOR=m1.tiny

function cleanUp() {

        local admin_rc=$1
	source ${admin_rc}
	keystone user-delete batman
	keystone tenant-delete gotham
}


function do_user_stuff(){

        local msg
	local testNum=39
	echo -n "39: keystone user-create --name batman --pass="secrete" --email=batman@isi.edu"
	local UserID=`keystone user-create --name batman --pass="secrete" --email=batman@isi.edu | grep id | awk '{print $4}'`
	local len=`expr length $UserID`
	if [ "$len" -ne "32" ]
	then
		msg="Step#39. Keystone user-create failed, exiting."
		echo "${msg}"
                write_log "${msg}" "${log}"
		return 1
	else
		msg="Step#39. is Successfully DONE."
		echo "${msg}"
                write_log "${msg}" "${log}"
	fi

	testNum=40
	echo -n "40: keystone tenant-create --name=gotham"
	local TenantID=`keystone tenant-create --name=gotham | grep id | awk '{print $4}'`
	len=`expr length $TenantID`
	if [ "$len" -ne "32" ]
	then
		msg="Step# ${testNum} keystone tenant-create failed, exiting"
		echo "${msg}"
                write_log "${msg}" "${log}"
		return 1
	else
		msg="Step# ${testNum} is Successfully DONE"
		echo "${msg}"
                write_log "${msg}" "${log}"
	fi 
	#get a role, we'll use the Member role
	local RoleID=`keystone role-list | grep Member | awk '{print $2}'`
	len=`expr length $RoleID`

	if [ "$len" -ne "32" ]
        then
                msg="keystone role-list failed, exiting"
		echo "${msg}"
                write_log "${msg}" "${log}"
                return 1
        fi
	testNum=41
	echo -n "41: keystone user-role-add --user-id $UserID --role-id $RoleID --tenant-id $TenantID"
	keystone user-role-add --user-id $UserID --role-id $RoleID --tenant-id $TenantID
	if [ "$?" -ne "0" ];
        then
                msg="keystone user-role-add failed, exiting."
		echo "${msg}"
                write_log "${msg}" "${log}"
                return 1
	else
		msg="Step#${testNum} Successfully DONE"
		echo "${msg}"
                write_log "${msg}" "${log}"
        fi
	testNum=41
	echo -n "41.5: keystone user-role-list --user-id $UserID --tenant-id $TenantID | grep $RoleID"
	keystone user-role-list --user-id $UserID --tenant-id $TenantID | grep $RoleID
	if [ "$?" -ne "0" ];
        then
                msg="keystone user-role-list failed, exiting."
		echo "${msg}"
                write_log "${msg}" "${log}"
                return 1
	else
		echo " success"
        fi

	testNum=42
	echo -n "42: keystone user-role-remove --user-id $UserID --role-id $RoleID --tenant-id $TenantID"	
	keystone user-role-remove --user-id $UserID --role-id $RoleID --tenant-id $TenantID
#	if [ "$RET" -ne "0" ];
	if [ "$?" -ne "0" ]
	then
                msg="Step#${testNum} keystone user-role-remove failed, exiting."
		echo "${msg}"
                write_log "${msg}" "${log}"
                return 1
	else
		msg="Step#${testNum} Successfully DONE"
		echo "${msg}"
                write_log "${msg}" "${log}"
	fi
	
	testNum=43
	echo -n "43: keystone tenant-delete $TenantID"
	keystone tenant-delete $TenantID
	if [ "$?" -ne "0" ];
	then
		msg="Step#${testNum} keystone tenant-delete failed, exiting."
		echo "${msg}"
                write_log "${msg}" "${log}"
		return 1
	else
		msg="Step#${testNum} Successfully DONE"
	fi

	testNum=44
	echo -n "44: keystone user-delete $UserID"
	keystone user-delete $UserID
	if [ "$?" -ne "0" ];
	then
		msg="Step#${testNum} keystone user-delete failed, exiting."
		echo "${msg}"
                write_log "${msg}" "${log}"
		return 1
	else
		msg="Step#${testNum} Successfully DONE"
		echo "${msg}"
                write_log "${msg}" "${log}"
	fi
	
	return 0
}

# The MAIN Function that should be called
function tests_39_to_52() {

    LOGFILE=$1
    local admin_rc=$2
    OPENRC_DEMO1=$3
    OPENRC_DEMO2=$4
    FLAVOR=$5
    IMAGE=$6
    TIMEOUT=$7

    echo " ============================================================== "
    echo " ================ Starting Tests 39-52 ======================== "
    echo " ============================================================== "

    # expects admin openrc file to be sourced
    echo "Sourcing admin operc file: ${admin_rc}"
    source $admin_rc

    do_user_stuff
    if [ "$?" -ne "0" ];
    then
	echo "Something failed in do_user_stuff"
	cleanUp "${admin_rc}"
	exit 1

    fi
    do_create_keypair $OPENRC_DEMO1 $KEYNAME
    if [ "$?" -ne "0" ];
    then
        echo "Something failed in do_create_keypair"
        cleanUp "${admin_rc}"
        exit 1

    fi
    do_create_keypair $OPENRC_DEMO2 $KEYNAME_2
    if [ "$?" -ne "0" ];
    then
        echo "Something failed in do_create_keypair"
        cleanUp "${admin_rc}"
        exit 1
	
    fi

    source $OPENRC_DEMO1

    INSTANCE_NAME=`mktemp -u`
    echo -n "45: nova boot --flavor $FLAVOR  --image $IMAGE --key_name $KEYNAME $INSTANCE_NAME"
    IMAGE_ID=`nova boot --flavor $FLAVOR  --image $IMAGE --key_name $KEYNAME $INSTANCE_NAME | grep "id" | grep -v tenant_id | grep -v user_id | awk '{print $4}'`
    for j in `seq 1 61`; do
	sleep 2
	RET=`nova show $IMAGE_ID | grep -i active`
	if [ $? -eq 0 ]; then
	    break
	fi

	if [ $j -eq "31" ]; then
            msg="Failed to launch instance"
	    echo "${msg}"
            write_log "${msg}" "${log}"
            cleanUp "${admin_rc}"
            exit 1
        fi
	
    done
    PUBLIC_IP=`nova show $IMAGE_ID | grep "public network" | awk '{print $5}'`
    
    for j in `seq 1 31`; do
	sleep 2
	RET=`ping_host $PUBLIC_IP`
	if [ $RET -eq 0 ]; then
	    echo "success"
            break
        fi
	if [ $j -eq "31" ]; then
	    msg="Failed to ping instance"
	    echo "${msg}"
            write_log "${msg}" "${log}"
	    cleanUp "${admin_rc}"
	    exit 1
	fi
    done
    
    echo -n "46: ssh -o "StrictHostKeyChecking no,BatchMode yes" -i $KEYNAME root@$PUBLIC_IP ls > /dev/null"
    for i in `seq 1 $TIMEOUT`; do
	ssh -o "StrictHostKeyChecking no" -o "BatchMode yes" -i $KEYNAME root@$PUBLIC_IP ls > /dev/null
	if [ $? -eq 0 ]; then
	    echo " success"
	    break
	fi
	if [ "$i" -eq "$TIMEOUT" ]; then
	    msg="Failed to log into instance."
	    echo "${msg}"
            write_log "${msg}" "${log}"
	    exit 1
	fi
    done

    source $OPENRC_DEMO2
    testNum=47
    echo -n "47: ssh -o "StrictHostKeyChecking no,BatchMode yes" -i $KEYNAME_2 root@$PUBLIC_IP ls > /dev/null"
    ssh -o "StrictHostKeyChecking no" -o "BatchMode yes" -i $KEYNAME_2 root@$PUBLIC_IP ls > /dev/null
    if [ $? -eq 0 ]; then
	msg="Step# ${testNum} FAILED: Logged into VM as unauthorized user"
	echo "${msg}"
        write_log "${msg}" "${log}"
	exit 1
    else
	echo " success"
    fi
    source $OPENRC_DEMO1
    
    testNum=48
    echo -n "48: nova boot --flavor $FLAVOR  --image $UNAUTHORIZED_IMAGE --key_name $KEYNAME $INSTANCE_NAME"
    RET=`nova boot --flavor $FLAVOR  --image $UNAUTHORIZED_IMAGE --key_name $KEYNAME $INSTANCE_NAME`
    if [ "$?" -ne "1" ];
    then
	msg="Step#${testNum} Failed. Booted an unauthorized image"
	echo "${msg}"
        write_log "${msg}" "${log}"
    else
	echo " success."
    fi
    
    testNum=49
    INSTANCE_NAME=`mktemp -u`
    echo -n "49: nova boot --flavor $FLAVOR  --image $IMAGE --key_name $KEYNAME --num-instances 2 $INSTANCE_NAME"
    RET=`nova boot --flavor $FLAVOR  --image $IMAGE --key_name $KEYNAME --num-instances 2 $INSTANCE_NAME `
    IMAGE1_ID=`nova list | grep $INSTANCE_NAME | awk {'print $2}' | head -n 1`
    IMAGE2_ID=`nova list | grep $INSTANCE_NAME | awk {'print $2}' | tail -n 1`
    
    for j in `seq 1 31`; do
        sleep 2
        RET=`nova show $IMAGE1_ID | grep -i active`
        if [ $? -eq 0 ]; then
            break
        fi
	
        if [ $j -eq "31" ]; then
                msg="Step#${testNum} Failed: Failed to launch instance"
		echo "${msg}"
                write_log "${msg}" "${log}"
                cleanUp "${admin_rc}"
                exit 1
        fi
	
    done
    PUBLIC1_IP=`nova show $IMAGE1_ID | grep "public network" | awk '{print $5}'`
    
for j in `seq 1 31`; do
    sleep 2
    RET=`ping_host $PUBLIC1_IP`
    if [ $RET -eq 0 ]; then
        break
    fi
    if [ $j -eq "31" ]; then
        msg="Failed to ping instance"
	echo "${msg}"
        write_log "${msg}" "${log}"
        cleanUp "${admin_rc}"
        exit 1
    fi
done

for j in `seq 1 31`; do
    sleep 2
    RET=`nova show $IMAGE2_ID | grep -i active`
    if [ $? -eq 0 ]; then
        break
    fi
    
    if [ $j -eq "31" ]; then
        msg="Failed to launch instance"
	echo "${msg}"
        write_log "${msg}" "${log}"
        cleanUp "${admin_rc}"
        exit 1
        fi
    
done
PUBLIC2_IP=`nova show $IMAGE2_ID | grep "public network" | awk '{print $5}'`

for j in `seq 1 31`; do
    sleep 2
    RET=`ping_host $PUBLIC2_IP`
    if [ $RET -eq 0 ]; then
        echo " success"
        break
    fi
    if [ $j -eq "31" ]; then
                msg="Failed to ping instance"
		echo "${msg}"
                write_log "${msg}" "${log}"
                cleanUp "${admin_rc}"
                exit 1
    fi
done

source $OPENRC_DEMO2
testNum=52
echo -n "52: nova delete $IMAGE_ID (as an unauthorized user)"
RET=`nova delete $IMAGE_ID`
source $OPENRC_DEMO1
RET=`nova list | grep -c $IMAGE_ID`
if [ "$RET" -ne "1" ];
then
    msg="Step#${testNum} Failed: Delete image as an unauthorized user worked, fail."
    echo "${msg}"
    write_log "${msg}" "${log}"
    cleanUp "${admin_rc}"
    exit 1
else
    echo " success."
fi

source $OPENRC_DEMO1
testNum=50
echo -n "50: nova delete $IMAGE_ID"
RET=`nova delete $IMAGE_ID`
for i in `seq 1 $TIMEOUT`; do
    sleep 2
    RET=`nova list | grep -c $IMAGE_ID`
    if [ "$RET" -eq "0" ]; then
	echo " success."
		break
    fi
    
    if [ "$i" -eq "$TIMEOUT" ]; then
	msg="Step# ${testNum} Failed. Delete image as authorized user failed."
	echo "${msg}"
	write_log "${msg}" "${log}"
	exit 1
	
    fi

done

testNum=51
echo -n "51: nova delete $IMAGE1_ID $IMAGE2_ID"
RET=`nova delete $IMAGE1_ID $IMAGE2_ID`
for i in `seq 1 $TIMEOUT`; do
    sleep 2
    RET=`nova list | grep -c "$IMAGE1_ID\|$IMAGE2_ID"`
    if [ "$RET" -eq "0" ]; then
        echo " success."
        break
    fi
    
    if [ "$i" -eq "$TIMEOUT" ]; then
        msg="Step#${testNum} Delete image as authorized user failed."
	echo "${msg}"
	write_log "${msg}" "${log}"
        exit 1
	
    fi
    
    
done


do_delete_keypair $OPENRC_DEMO1 $KEYNAME
if [ "$?" -ne "0" ];
then
        echo "Something failed in do_delete_keypair"
        cleanUp "${admin_rc}"
        exit 1

fi
do_delete_keypair $OPENRC_DEMO2 $KEYNAME_2
if [ "$?" -ne "0" ];
then
        echo "Something failed in do_delete_keypair"
        cleanUp "${admin_rc}"
        exit 1

fi


} # End of Function