#!bin/bash

# regression-test.sh
# Malek Musleh                                                                                                       
# mmusleh@isi.edu                                                                                                    
# May. 15, 2013                                                                                                      
#                                                                                                                  
# (c) 2013 USC/ISI


# Source in necessary helper and sub-scripts
source functions.sh
source glance.sh
source volume.sh


source tests_7_to_14.sh
source tests_15_to_27.sh
source tests_28_to_38.sh
source tests_39_to_52.sh
source tests_53_to_65.sh
source tests_66_to_76.sh

declare LOG_FILE
declare USER
declare FLAVOR=m1.tiny
declare OPENRC_PATH=./
declare OPENRC_ROOT=/root/openrc
declare OPENRC_DEMO1=openrc-demo1
declare OPENRC_DEMO2=openrc-demo2
declare HYPERVISOR=kvm
declare IMAGE=kvm_fs
declare TIMEOUT=60
declare SLEEP=100
declare TEST_NUM
declare START_TEST_NUM=0
declare END_TEST_NUM=76
declare DELETE_IMAGES=false

export LANG=C

function usage() {
    cat << USAGE
Syntax
-d (delete images? default: false)
-h (hypervisor LXC or KVM, default KVM)
-f (flavor, default m1.tiny)
-i (image, default kvm_fs)
-r (openrc_root full path, default /root/openrc)
-p (path to openrc-demo1/2, default /root/jp_scripts/)
-l (log file for test outputs (Pass/Fail)
-m (the Member role, default Member)
-n (network, default public)
-u (user, default root)
-S (Start Test Number)
-E (End Test Number)
-s (SLEEP Period to wait for instances to run)
-t (TimeOut Period: default 60 Seconds)

e.g: sh tests_39_to_52.sh -h LXC -f cg1.medium -i lxc-fs -r /root/keystonerc -m _member_ -n net1 -p /root/ -u nova

e.g. clear; bash regression-test.sh -r /root/openrc -l log.txt

USAGE
    exit 1
}

function verify_test() {

    cat << CONFIG

LOG_FILE: ${LOG_FILE}
USER: ${USER}
OPENRC_ROOT: ${OPENRC_ROOT}
OPENRC_PATH: ${OPENRC_PATH}
OPENRC_DEMO1: ${OPENRC_DEMO1}
OPENRC_DEMO2: ${OPENRC_DEMO2}
HYPERVISOR: ${HYPERVISOR}
FLAVOR: ${FLAVOR}
SLEEPTIME: ${SLEEP}
TIMEOUT: ${TIMEOUT}
START_TEST: ${START_TEST_NUM}
END_TEST: ${END_TEST_NUM}
DELETE_IMAGES: ${DELETE_IMAGES}
CONFIG

INSTALLMSG="TEST Scripts will run with the above parameters \n
Are you sure you want to continue? [Y/n]"

if [ -z ${AUTO} ]
then
    echo -e ${INSTALLMSG}
    read input
    if [ "${input}" = "no" ] || [ "${input}" = "n" ]
        then
        echo "Aborting Test Process"
        exit 1
    else
        echo "Continuing Tests..."
    fi
fi

}


# Function to process command line options
function do_get_options(){

    echo "Processing Command Line Parameters..."
    opts="$@"

    while getopts d:h:f:i:r:p:u:t:m:n:l:S:E:s: opts
    do
        case ${opts} in
	    d)
		DELETE_IMAGES=true
		;;
            n)
                NETWORK=${OPTARG}
                ;;
            h)
                HYPERVISOR=${OPTARG}
                ;;
	    f)
		FLAVOR=${OPTARG}
                ;;
            i)
                IMAGE=${OPTARG}
		;;
	    r)
		OPENRC_ROOT=${OPTARG}
		;;
	    l)
		LOG_FILE=${OPTARG}
		;;
	    p)
		OPENRC_PATH=${OPTARG}
                OPENRC_DEMO1=$OPTARG/openrc-demo1
		OPENRC_DEMO2=$OPTARG/openrc-demo2
		;;
	    u)
                USER=${OPTARG}
                ;;
	    S)
		START_TEST_NUM=${OPTARG}
		TEST_NUM=${START_TEST_NUM}
		;;
	    E)
		END_TEST_NUM=${OPTARG}
		;;
	    s)
		SLEEP=${OPTARG}
		;;
            t)
                TIMEOUT=${OPTARG}
                ;;
            m)
                MEMBER=${OPTARG}
                ;;
	    
            \?)
                echo "Invalid option -$OPTARG"
		usage
		;;
	    
            :)
                echo "Option -$OPTARG requires argument."
		usage
		;;
	    
	esac
	
    done	
}

# Function to initialize + setup the environment for
# openstack testing

function init_env() {

    echo "Initializing test-environment"
    
    remove_known_hosts

    # Clean up environment prior to new initialization
    cleanup_env "${DELETE_IMAGES}"

    # Start log activity for Tests Pass/Fail
    start_log "${LOG_FILE}"

    keystone tenant-create --name demo_tenant1
    keystone tenant-create --name demo_tenant2
    keystone tenant-list | grep demo_tenant1
    DEMO1=`keystone tenant-list | grep demo_tenant1 | awk '{ print $2 }'`
    DEMO2=`keystone tenant-list | grep demo_tenant2 | awk '{ print $2 }'`
    echo "$DEMO1"
    echo "$DEMO2"
    keystone user-create --name demo1 --tenant-id "$DEMO1" --pass "demo1_secrete"
    keystone user-create --name demo2 --tenant-id "$DEMO2" --pass "demo2_secrete"
    unset SERVICE_TOKEN
    unset SERVICE_ENDPOINT
    keystone --os-user demo1 --os-password demo1_secrete --os-tenant-name demo_tenant1 --os-auth-url=http://localhost:5000/v2.0/  ec2-credentials-create > /tmp/openstack-demo1
    ACCESS1=`grep access /tmp/openstack-demo1 | awk '{ print $4}'`
    SECRET1=`grep secret /tmp/openstack-demo1 | awk '{ print $4}'`
    echo "access1 = $ACCESS1"
    echo "secrete1 = $SECRET1"
    keystone --os-user demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  ec2-credentials-create > /tmp/openstack-demo2
    ACCESS2=`grep access /tmp/openstack-demo2 | awk '{ print $4}'`
    SECRET2=`grep secret /tmp/openstack-demo2 | awk '{ print $4}'`
    echo "access2 = $ACCESS2"
    echo "secrete2 = $SECRET2"
    
    echo "Deleting old file: ${OPENRC_DEMO1} before generating new credentials"
    rm ${OPENRC_DEMO1}

    echo "writing generating ${OPENRC_DEMO1}"
    echo "export OS_USERNAME=demo1" > ${OPENRC_DEMO1}
    echo "export OS_PASSWORD=demo1_secrete" >> ${OPENRC_DEMO1}
    echo "export OS_TENANT_NAME=demo_tenant1" >> ${OPENRC_DEMO1}
    echo "export OS_AUTH_URL=http://127.0.0.1:5000/v2.0/" >> ${OPENRC_DEMO1}
    echo "export EC2_ACCESS_KEY=$ACCESS1" >> ${OPENRC_DEMO1}
    echo "export EC2_SECRET_KEY=$SECRET1" >> ${OPENRC_DEMO1}
    echo "export EC2_URL=http://127.0.0.1:8773/services/Cloud" >> ${OPENRC_DEMO1}
    echo "export S3_URL=http://127.0.0.1:3333" >> ${OPENRC_DEMO1}
    echo "export EC2_USER_ID=42" >> ${OPENRC_DEMO1}

    echo "Deleting old file: ${OPENRC_DEMO2} before generating new credentials"
    rm ${OPENRC_DEMO2}

    echo "writing generating ${OPENRC_DEMO2}"
    echo "export OS_USERNAME=demo2" > ${OPENRC_DEMO2}
    echo "export OS_PASSWORD=demo2_secrete" >> ${OPENRC_DEMO2}
    echo "export OS_TENANT_NAME=demo_tenant2" >> ${OPENRC_DEMO2}
    echo "export OS_AUTH_URL=http://127.0.0.1:5000/v2.0/" >> ${OPENRC_DEMO2}
    echo "export EC2_ACCESS_KEY=$ACCESS2" >> ${OPENRC_DEMO2}
    echo "export EC2_SECRET_KEY=$SECRET2" >> ${OPENRC_DEMO2}
    echo "export EC2_URL=http://127.0.0.1:8773/services/Cloud" >> ${OPENRC_DEMO2}
    echo "export S3_URL=http://127.0.0.1:3333" >> ${OPENRC_DEMO2}
    echo "export EC2_USER_ID=42" >> ${OPENRC_DEMO2}
    
    source ${OPENRC_DEMO1}
    echo "add KVM image to glance for demo1"
    DEMO1_KERNEL=`glance --os_username demo1 --os-password demo1_secrete --os-tenant-name demo_tenant1 --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_vmlinux" is_public=false container_format=aki disk_format=aki < ttylinux-uec-amd64-12.1_2.6.35-22_1-vmlinuz | awk '{ print $6 } '`
    DEMO1_INITRD=`glance --os_username demo1 --os-password demo1_secrete --os-tenant-name demo_tenant1 --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_initrd" is_public=false container_format=ari disk_format=ari < ttylinux-uec-amd64-12.1_2.6.35-22_1-initrd | awk '{ print $6 } '`
    glance --os_username demo1 --os-password demo1_secrete --os-tenant-name demo_tenant1 --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_fs" is_public=false container_format=ami disk_format=ami kernel_id="$DEMO1_KERNEL" ramdisk_id="$DEMO1_INITRD" < ttylinux-uec-amd64-12.1_2.6.35-22_1.img | awk '{ print $6 } '

    echo "add LXC image to glance for demo1"
    glance --os_username demo1 --os-password demo1_secrete --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_lxc_fs" is_public=false container_format=ami disk_format=ami < lxc-sudo-fs
    
    echo "create volume for demo1"
    nova volume-create --display-name "demo1" 1
    

    source ${OPENRC_DEMO2}
    echo "add KVM image to glance for demo2"
    DEMO2_KERNEL=`glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_vmlinux" is_public=false container_format=aki disk_format=aki < ttylinux-uec-amd64-12.1_2.6.35-22_1-vmlinuz | awk '{ print $6 } '`
    
    DEMO2_INITRD=`glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_initrd" is_public=false container_format=ari disk_format=ari < ttylinux-uec-amd64-12.1_2.6.35-22_1-initrd | awk '{ print $6 } '`
    
    glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_fs" is_public=false container_format=ami disk_format=ami kernel_id="$DEMO2_KERNEL" ramdisk_id="$DEMO2_INITRD" < ttylinux-uec-amd64-12.1_2.6.35-22_1.img | awk '{ print $6 } '
    
    echo "add LXC image to glance for demo2"
    glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_lxc_fs" is_public=false container_format=ami disk_format=ami < lxc-sudo-fs
    
    echo "create volume for demo2"
    nova volume-create --display-name "demo2" 1

    create_lxc_flavor
}

# Function to create nova flavors for LXC testing
function create_lxc_flavor() {

    echo "Sourcing root credentials: ${OPENRC_ROOT} to create LXC Flavors"
    source ${OPENRC_ROOT}

    echo "Creating cg1.medium flavor"
    nova flavor-create --is-public True cg1.medium 11 4096 20 2
    nova flavor-key 11 set gpus="= 1"
    nova flavor-key 11 set gpu_arch="s== fermi"
    nova flavor-key 11 set cpu_arch="s== x86_64"
    nova flavor-key 11 set hypervisor_type="s== LXC"
        
}

function clean_gpu_allocation() {

    echo "Manually removing gpus_allocated file to ensure clean GPU-deallocation"
    sleep 10 # small delay to give nova proper time to deallocate gpus
    rm /var/lib/nova/gpus_allocated
}

# Function to do full clean
function cleanup_env() {

    local delete_images=$1

    echo "======================================================"
    echo "------ Cleaning Up All Instances/Images/Volumes ------"
    echo "======================================================"

    delete_all_instances "${OPENRC_ROOT}"
    delete_all_instances "${OPENRC_DEMO1}"
    delete_all_instances "${OPENRC_DEMO2}"

    if [ "${delete_images}" == "true" ]
    then
	clean_glance_repo "${OPENRC_ROOT}"
	clean_glance_repo "${OPENRC_DEMO1}"
	clean_glance_repo "${OPENRC_DEMO2}"

	echo "removing any leftover glance images..."
	rm -rf /var/lib/glance/images/*
    else
	echo "Not deleting Glance Images"
    fi

    delete_all_volumes "${OPENRC_ROOT}"
    delete_all_volumes "${OPENRC_DEMO1}"
    delete_all_volumes "${OPENRC_DEMO2}"

    euca_delete_keypair "openrc-demo1" "demo1"
    euca_delete_keypair "openrc-demo2" "demo2"
    
    clean_gpu_allocation
    
    echo "Removing any leftover nova instances..."
    rm -rf /var/lib/nova/instances/_base/*
    #rm -rf /var/lib/nova/instances/*-*

    echo "Cleanup DONE!"
}


####### MAIN ########


if [ $# -gt 0 ]; then
    echo "Your command line contains $# arguments"
else
    echo "Your command line contains no arguments"
fi

# process command line parameters
do_get_options "$@"

verify_test

# Initialize the testing environment
init_env

# Mikyung's tests
if [[ ${TEST_NUM} -lt "7" ]]
then
    tests_7_to_14 "${LOG_FILE}" "${OPENRC_PATH}" "${HYPERVISOR}" "${FLAVOR}" "${USER}" "${TIMEOUT}" "${SLEEP}"
    TEST_NUM=15
else
    echo "Skipping Tests:7-14"
fi

# Malek's tests
if [[ ${TEST_NUM} -gt "14" ]] && [[ ${TEST_NUM} -lt "27" ]]
then
    echo "Cleanup of all instances/volumes but NOT IMAGES before next Set of Tests"
    delete_all_instances "${OPENRC_DEMO1}"
    delete_all_instances "${OPENRC_DEMO2}"
    delete_all_volumes "${OPENRC_DEMO1}"
    delete_all_volumes "${OPENRC_DEMO2}"
    clean_gpu_allocation
    tests_15_to_27 "${LOG_FILE}" "${OPENRC_PATH}" "${HYPERVISOR}" "${FLAVOR}" "${USER}" "${TIMEOUT}" "${SLEEP}"
    TEST_NUM=28
else
    echo "Skipping Tests:15-27"
fi

# Charles tests
if [[ ${TEST_NUM} -gt "27" ]] && [[ ${TEST_NUM} -lt "38" ]]
then
    echo "Cleanup before next Set of Tests"
    cleanup_env "${DELETE_IMAGES}"
    tests_28_to_38 "${LOG_FILE}" "${OPENRC_ROOT}" "${OPENRC_PATH}" "${TIMEOUT}"
    TEST_NUM=39
else
    echo "Skipping Tests:28-38"
fi

# JP's tests
if [[ ${TEST_NUM} -gt "38" ]] && [[ ${TEST_NUM} -lt "52" ]]
then
    echo "Cleanup before next Set of Tests"
    cleanup_env "${DELETE_IMAGES}"
    tests_39_to_52 "${LOG_FILE}" "${OPENRC_ROOT}" "${OPENRC_DEMO1}" "${OPENRC_DEMO2}" "${FLAVOR}" "${IMAGE}" "${TIMEOUT}"
    TEST_NUM=53
else
    echo "Skipping Tests: 39-52"
fi

# TK's tests
if [[ ${TEST_NUM} -gt "52" ]] && [[ ${TEST_NUM} -lt "65" ]]
then
    echo "Cleanup before next Set of Tests"
    delete_all_instances "${OPENRC_DEMO1}"
    delete_all_instances "${OPENRC_DEMO2}"
    delete_all_volumes "${OPENRC_DEMO1}"
    delete_all_volumes "${OPENRC_DEMO2}"

    tests_53_to_65 "${LOG_FILE}" "${IMAGE}" "${HYPERVISOR}" "${TIMEOUT}"
    TEST_NUM=66
else
    echo "Skipping Tests: 53-65"
fi

# Ke-thia's tests
if [[ ${TEST_NUM} -gt "65" ]] && [[ ${TEST_NUM} -lt "76" ]]
then
    echo "Cleanup before next Set of Tests"
    cleanup_env
    
    tests_66_to_76 "${LOG_FILE}" "${OPENRC_DEMO1}" "${OPENRC_DEMO2}" "${TIMEOUT}"
else
    echo "Skipping Tests:66-76"
fi

# Cleanup environment
cleanup_env