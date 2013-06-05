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

declare START_TEST_NUM=0
declare END_TEST_NUM=76

export LANG=C

function usage() {
    cat << USAGE
Syntax
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


function do_get_options(){

    echo "Processing Command Line Parameters..."
    opts="$@"

    while getopts h:f:i:r:p:u:t:m:n:l:S:E: opts
    do
        case ${opts} in
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
                KVM_IMAGE=${OPTARG}
		;;
	    r)
		OPENRC_ROOT=${OPTARG}
		;;
	    l)
		LOG_FILE=${OPTARG}
		;;
	    p)
                OPENRC_DEMO1=$OPTARG/openrc-demo1
		OPENRC_DEMO2=$OPTARG/openrc-demo2
		;;
	    u)
                USER=${OPTARG}
                ;;
	    S)
		START_TEST_NUM=${OPTARG}
		;;
	    E)
		END_TEST_NUM=${OPTARG}
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
    
    echo "writing generating openrc-demo1"
    echo "export OS_USERNAME=demo1" > openrc-demo1
    echo "export OS_PASSWORD=demo1_secrete" >> openrc-demo1
    echo "export OS_TENANT_NAME=demo_tenant1" >> openrc-demo1
    echo "export OS_AUTH_URL=http://127.0.0.1:5000/v2.0/" >> openrc-demo1
    echo "export EC2_ACCESS_KEY=$ACCESS1" >> openrc-demo1
    echo "export EC2_SECRET_KEY=$SECRET1" >> openrc-demo1
    echo "export EC2_URL=http://127.0.0.1:8773/services/Cloud" >> openrc-demo1
    echo "export S3_URL=http://127.0.0.1:3333" >> openrc-demo1
    echo "export EC2_USER_ID=42" >> openrc-demo1

    echo "writing generating openrc-demo2"
    echo "export OS_USERNAME=demo2" > openrc-demo2
    echo "export OS_PASSWORD=demo2_secrete" >> openrc-demo2
    echo "export OS_TENANT_NAME=demo_tenant2" >> openrc-demo2
    echo "export OS_AUTH_URL=http://127.0.0.1:5000/v2.0/" >> openrc-demo2
    echo "export EC2_ACCESS_KEY=$ACCESS2" >> openrc-demo2
    echo "export EC2_SECRET_KEY=$SECRET2" >> openrc-demo2
    echo "export EC2_URL=http://127.0.0.1:8773/services/Cloud" >> openrc-demo2
    echo "export S3_URL=http://127.0.0.1:3333" >> openrc-demo2
    echo "export EC2_USER_ID=42" >> openrc-demo2
    
    source ./openrc-demo1
    echo "add KVM image to glance for demo1"
    DEMO1_KERNEL=`glance --os_username demo1 --os-password demo1_secrete --os-tenant-name demo_tenant1 --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_vmlinux" is_public=false container_format=aki disk_format=aki < ttylinux-uec-amd64-12.1_2.6.35-22_1-vmlinuz | awk '{ print $6 } '`
    DEMO1_INITRD=`glance --os_username demo1 --os-password demo1_secrete --os-tenant-name demo_tenant1 --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_initrd" is_public=false container_format=ari disk_format=ari < ttylinux-uec-amd64-12.1_2.6.35-22_1-initrd | awk '{ print $6 } '`
    glance --os_username demo1 --os-password demo1_secrete --os-tenant-name demo_tenant1 --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_fs" is_public=false container_format=ami disk_format=ami kernel_id="$DEMO1_KERNEL" ramdisk_id="$DEMO1_INITRD" < ttylinux-uec-amd64-12.1_2.6.35-22_1.img | awk '{ print $6 } '

    echo "add LXC image to glance for demo1"
    glance --os_username demo1 --os-password demo1_secrete --os-auth-url=http://localhost:5000/v2.0/  add name="demo1_lxc_fs" is_public=false container_format=ami disk_format=ami < lxc-sudo-fs
    
    echo "create volume for demo1"
    nova volume-create --display-name "demo1" 1
    

    source ./openrc-demo2
    echo "add KVM image to glance for demo2"
    DEMO2_KERNEL=`glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_vmlinux" is_public=false container_format=aki disk_format=aki < ttylinux-uec-amd64-12.1_2.6.35-22_1-vmlinuz | awk '{ print $6 } '`
    
    DEMO2_INITRD=`glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_initrd" is_public=false container_format=ari disk_format=ari < ttylinux-uec-amd64-12.1_2.6.35-22_1-initrd | awk '{ print $6 } '`
    
    glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_fs" is_public=false container_format=ami disk_format=ami kernel_id="$DEMO2_KERNEL" ramdisk_id="$DEMO2_INITRD" < ttylinux-uec-amd64-12.1_2.6.35-22_1.img | awk '{ print $6 } '
    
    echo "add LXC image to glance for demo2"
    glance --os_username demo2 --os-password demo2_secrete --os-tenant-name demo_tenant2 --os-auth-url=http://localhost:5000/v2.0/  add name="demo2_lxc_fs" is_public=false container_format=ami disk_format=ami < lxc-sudo-fs
    
    echo "create volume for demo2"
    nova volume-create --display-name "demo2" 1
}


function cleanup_env() {

    echo "Cleanup_env ------"
    clean_glance_repo "openrc_demo1"
    clean_glance_repo "openrc_demo2"
    
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
tests_7_to_14 "${LOG_FILE}"

# Malek's tests
tests_15_to_27 "${LOG_FILE}"

# Charles tests
#tests_28_to_38 "${LOG_FILE}" "${OPENRC_ROOT}"

# JP's tests
#tests_39_to_52 "${LOG_FILE}" "${OPENRC_ROOT}" "${OPENRC_DEMO1}" "${OPENRC_DEMO2}"

# TK's tests
#tests_53_to_65 "${LOG_FILE}"

#tests_66_to_76 "${LOG_FILE}"


# Cleanup environment
cleanup_env