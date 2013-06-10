#!/bin/bash

source functions.sh
source glance.sh
source volume.sh

function tests_7_to_14() {

    local log=$1
    local openrc_path=$2
    local LIBVIRT_TYPE=$3
    local FLAVOR=$4
    local USER=$5
    local TIMEOUT=$6
    local openrc
    local msg
    local msg2

    TENANT1=demo1
    TENANT2=demo2
    INST_CNT=3
    INST_CNT_1=`expr $INST_CNT - 1`
    
    TENANT="
$TENANT1
$TENANT2
"


    echo " ============================================================== "
    echo " ================ Starting Tests 7-14  ======================== "
    echo " ============================================================== "

    for j in $TENANT; do
	
	echo " "
	echo "[$LIBVIRT_TYPE] $j TESTING ============================================================="
	openrc="${openrc_path}openrc-$j"

	echo "Sourcing openrc file: ${openrc} for TENANT: $j"
	source ${openrc}
	
	if [ "$LIBVIRT_TYPE" = "kvm" ]; then
	    IMG_NAME=`euca-describe-images | grep $j | grep fs | grep -v lxc | grep ami | awk '{ print $2 }' | head -n 1`
	elif [ "$LIBVIRT_TYPE" = "lxc" ]; then
	    IMG_NAME=`euca-describe-images | grep $j | grep lxc_fs | grep ami | awk '{ print $2 }' | head -n 1`
	fi
	    
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
	    sleep 60 
	    for k in `seq 1 $TIMEOUT`; do
		INST_ID=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print $2 }' | head -n 1`
		INST_IP=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print $15 }' | head -n 1`
		if [ -z $INST_IP ]; then
		    msg=" =====> Step#7. is not running yet: $INST_ID $INST_IP"
		    echo "${msg}"
		    write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#7. is successfully DONE: $INST_ID $INST_IP"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    break
		fi
	    done
	    echo " "
	    euca-describe-instances | grep $KEY_NAME | grep $INST_ID
	    
	    if [ $j == $TENANT1 ]; then
		echo " "
		echo "---------------------------------------------------------------------------"
		echo " 8. ssh -i ${openrc_path}$KEY $USER@$INST_IP"
		echo "---------------------------------------------------------------------------"
		for k in `seq 1 $TIMEOUT`; do
		    ssh -o "StrictHostKeyChecking no" -o "BatchMode yes" -i ${openrc_path}$KEY $USER@$INST_IP ls > /dev/null
  		    if [ $? -eq 0 ]; then
			msg=" =====> Step#8. is successfully DONE: $INST_ID $INST_IP"
			echo "${msg}"
                        write_log "${msg}" "${log}"
			break
		    fi
		    if [ "$k" -eq "$TIMEOUT" ]; then
			msg="Failed to log into instance."
			msg2=" =====> Step#8. Failed to ssh into $INST_ID $INST_IP"
			echo "${msg}"
			echo "${msg2}"
                        write_log "${msg}" "${log}"
			write_log "${msg2}" "${log}"
			exit 1
			fi
		done
		
		OTHER_INST_IP=$INST_IP
		OTHER_IMG_NAME=$IMG_NAME
		OTHER_INST_ID=$INST_ID
		OTHER_KEY_NAME=$KEY_NAME
	    fi
	    
	    if [ $j == $TENANT2 ]; then
		    
		echo " "
		echo "---------------------------------------------------------------------------"
		echo "12. euca-terminate-instances $INST_ID" 
		echo "---------------------------------------------------------------------------"
		RET=`euca-terminate-instances $INST_ID`
		sleep 20 
		for k in `seq 1 $TIMEOUT`; do
		    RET=`euca-describe-instances | grep $KEY_NAME | grep $INST_ID`
		    if [ "$RET" = "" ]; then
			msg=" =====> Step#12. is successfully DONE: $INST_ID"
			echo "${msg}"
                        write_log "${msg}" "${log}"
			break
  		    fi
		    msg=" =====> Step#12. $INST_ID is still existed."
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		done
		euca-describe-instances | grep $KEY_NAME | grep $INST_ID
		
		echo " "
		echo "---------------------------------------------------------------------------"
		echo "11. euca-run-instances -k $KEY_NAME -n $INST_CNT -t $FLAVOR $IMG_NAME"
		echo "---------------------------------------------------------------------------"
		RET=`euca-run-instances -k $KEY_NAME -n $INST_CNT -t $FLAVOR $IMG_NAME`
		echo " Please wait until $INST_CNT instances are running"
		sleep 60
		for k in `seq 1 $TIMEOUT`; do
		    RET=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print $2 }'`
		    MULTI_ID=$RET
		    IFS=$'\n'
		    ary=($RET)
		    ALL_SET=1
		    for n in `seq 0 $INST_CNT_1`; do
			if [ "${ary[$n]}" == "" ]; then
			    echo " =====> Step#11. is not running yet: ${ary[$n]}"
			    ALL_SET=0
			    break
			fi
			done
		    if [ $ALL_SET = 1 ]; then
			msg=" =====> Step#11. is successfully DONE:"
			echo "${msg}"
                        write_log "${msg}" "${log}"
			echo "$RET"
			    break
		    fi
		done
		echo " "
		euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running
		
		echo " "
		echo "---------------------------------------------------------------------------"
		echo "13. euca-terminate-instances $MULTI_ID"
		echo "---------------------------------------------------------------------------"
		for k in `seq 1 $TIMEOUT`; do
		    RET=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep running |  awk '{ print $2 }'`
		    IFS=$'\n'
		    ary=($RET)
		    RET2=`euca-terminate-instances $RET`
		    sleep 30
		    ALL_SET=1
		    for n in `seq 0 $INST_CNT_1`; do
			TERM=`euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME | grep ${ary[$n]} | awk '{ print $2 }'`
			if [ "$TERM" != "" ]; then
			    echo " =====> Step#13. still existed: ${ary[$n]}"
			    ALL_SET=0
			    break
			fi
		    done
		    if [ $ALL_SET = 1 ]; then
			msg=" =====> Step#13. is successfully DONE:"
			echo "${msg}"
                        write_log "${msg}" "${log}"
			echo "$RET"
			break
  		    fi
		done
		euca-describe-instances | grep $KEY_NAME | grep $IMG_NAME
		    
		echo " "
		echo "---------------------------------------------------------------------------"
		echo " 9. ssh -i ${openrc_path}$KEY $USER@$OTHER_INST_IP"
		echo "---------------------------------------------------------------------------"
		ssh -o "StrictHostKeyChecking no" -o "BatchMode yes" -i ${openrc_path}$KEY $USER@$OTHER_INST_IP ls > /dev/null
		if [ $? -eq 0 ]; then
		    msg=" =====> Step#9. FAIL: why can ssh into an unauthorized $OTHER_INST_IP"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		    exit 1
		else
		    msg=" =====> Step#9. is successfully DONE: CanNotSSH to $OTHER_INST_IP"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		fi
		
		echo " "
		echo "---------------------------------------------------------------------------"
		echo "10. euca-run-instances -k $KEY_NAME -t $FLAVOR $OTHER_IMG_NAME"
		echo "---------------------------------------------------------------------------"
		euca-run-instances -k $KEY_NAME -t $FLAVOR $OTHER_IMG_NAME
		RETVAL=$?
		if [ $RETVAL -eq 1 ]; then
		    msg=" =====> Step#10. is successfully DONE: $OTHER_IMG_NAME ImageNotFound"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		else
		    msg=" =====> Step#10. FAIL: why can launch using unauthorized image $OTHER_IMG_NAME"
		    echo "${msg}"
                    write_log "${msg}" "${log}"
		fi
		
		echo " "
		echo "---------------------------------------------------------------------------"
		echo "14. euca-terminate-instances $OTHER_INST_ID"
		echo "---------------------------------------------------------------------------"
		euca-terminate-instances $OTHER_INST_ID
		RETVAL=$?
		if [ $RETVAL -eq 1 ]; then
		    msg=" =====> Step#14. is successfully DONE: $OTHER_IMG_ID InstanceNotFound"
		    else
		    msg=" =====> Step#14. FAIL: why can terminate using unauthorized instance $OTHER_IMG_ID"
		fi
		echo "${msg}"
                write_log "${msg}" "${log}"
	    fi
	fi
    done
}