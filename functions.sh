#!/bin/bash

# function.sh
# Malek Musleh                                                                                                       
# mmusleh@isi.edu                                                                                                    
# May. 15, 2013                                                                                                      
#                                                                                                                    
# (c) 2013 USC/ISI                                                                                                   
#                                                                                                                    
# This script is provided for a reference only.                                                                      
# Its functional correctness is not guaranteed.                                                                      
# It contains helper functions related to volume usage in Openstack    

# Checks an environment variable is not set or has length 0 OR if the                            
# exit code is non-zero and prints "message" and exits                                                              
# NOTE: env-var is the variable name without a '$'                                                                   
# die_if_not_set $LINENO env-var "message"                                                                        

function die_if_not_set() {
    local exitcode=$?
    FXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local line=$1; shift
    local evar=$1; shift
    if ! is_set $evar || [ $exitcode != 0 ]; then
        die $line "$*"
    fi
    $FXTRACE
}

# Prints line number and "message" in error format                                                               
# err $LINENO "message"                                                                                          
function err() {
    local exitcode=$?
    errXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] $0:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $errXTRACE
    return $exitcode
}

# Create the log file (if necessary) and append a timestamp                                                       
function start_log() {
    # delete the log file if it exists from previous installation                                                
    local LOG_FILE=$1

    echo "starting log file: ${LOG_FILE}"

    rm -rf ${LOG_FILE}
    set -o xtrace
    touch ${LOG_FILE}
    chmod 600 ${LOG_FILE}
    set +o xtrace
    echo "$(date) $BASENAME: installation process initiated ($PARAMETERS)" >> $LOG_FILE

}

# Append msg to log file
function write_log() {
    local message="$1"
    local LOG_FILE="$2"
    sed -i'' -e '/^+ set +o xtrace$/d' $LOG_FILE
    echo "$(date) $message" >> $LOG_FILE
}

# Remove clutter from log and append a timestamp                                                              
function finalize_log() {
    local message="$1"
    local LOG_FILE="$2"
    sed -i'' -e '/^+ set +o xtrace$/d' $LOG_FILE
    echo "$(date) $BASENAME: $message ($PARAMETERS)" >> $LOG_FILE
}

# Function to pretty print step# and description of test
function print_test_msg() {
    local stepNum="$1"
    local message="$2"
    echo " "
    echo "---------------------------------------------------------------------------"
    echo " ${stepNum}: ${message}"
    echo "---------------------------------------------------------------------------"
    echo " "
}

# Function to pretty print step#, message, and command used
function print_test_command_msg() {
    local stepNum="$1"
    local message="$2"
    local command="$3"
    echo " "
    echo "---------------------------------------------------------------------------"
    echo " ${stepNum}: ${message}"
    echo " command: ${command}"
    echo "---------------------------------------------------------------------------"
    echo " "
}

# Function to ping host instance/machine
function ping_host(){
        ping -q -c 1 $1 > /dev/null 2>&1
        local myIP=$?
        echo $myIP
}

function remove_known_hosts() {

    local user=`whoami`

    if [ "${user}" == "root" ]
    then
	rm -rf /root/.ssh/known_hosts
    else
	RET=`rm -rf /home/${user}/.ssh/known_hosts`
    fi

}

# Grab a numbered field from python prettytable output             
# Fields are numbered starting with 1                                                                          
# Reverse syntax is supported: -1 is the last field, -2 is second to last, etc.                             
# get_field field-number                                                                                     
function get_field() {
    while read data; do
    if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
	    else
            field="\$$(($1 + 1))"
	    fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{print $field}"
    done
}


# Wait at most $1 seconds for cmd $2 to return a non-empty string.
# Returns status 0 command succeeded
function timeout_check() {
    seconds=$1
    cmd=$2
    # echo timeout_check $seconds $cmd
    ( cmdpid=$BASHPID;
	( sleep $seconds; kill $cmdpid &> /dev/null) \
	& while [ -z "`eval $cmd`" ]; do
	    sleep 5
	done 
    )
}



function get_status(){

        local mySTATUS=`nova show $1 | grep "status" | awk '{print $4}'`
        echo $mySTATUS
}

# TODO: The following 2 functions do the same, and should be merged
function makeAddKey {
  # $1 is keypair name, $2 is key file name to be created, $3 is nova params
  ssh-keygen -f $2 -N ''
  chmod 600 $2.pub
  nova $3 keypair-add --pub-key "$2.pub" $1
}

function do_create_keypair(){

        source $1
        if [ -e "$2" ];
        then
                return 0
        else
                ssh-keygen -N "" -f $2
                nova keypair-add --pub_key $2.pub $2
        fi
        return 0

}

# Test if the named environment variable is set and not zero length                                              
# is_set env-var                                                                                                  
function is_set() {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
}

function do_delete_keypair(){
        source $1
        nova keypair-delete $2
        rm -rf $2 $2.pub
        return 0
}

function euca_delete_keypair() {
    local rc=$1
    local name=$2
    local test

    echo "Deleting keypair: ${name} using credentials file: ${rc}"

    source $rc
    test=`euca-describe-keypairs | grep ${name} | awk '{ print $2 }' | head -n 1`
    echo "Deleting KeyPair: ${test}"
    
    euca-delete-keypair "${test}"
}

function sendSshAndGet {
  # $1 - result to be returned
  local keyfile=$2
  local ip=$3
  local cmd=$4
  local res=`ssh -i $keyfile -o StrictHostKeyChecking=no root@$ip $cmd`
  eval "$1='$res'"
}

