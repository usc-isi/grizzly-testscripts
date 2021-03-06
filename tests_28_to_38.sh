#!/bin/bash


source functions.sh
source volume.sh
source glance.sh

set -x

function tests_28_to_38() {

    local log=$1
    local openrc_admin=$2
    local openrc_demo1=$3
    local openrc_demo2=$4
    local openrc_path=$5
    local timeoutWait=$6
    local sleepWait=$7
    local openrc
    local msg

    echo " ============================================================== "
    echo " ================ Starting Tests 28-38 ======================== "
    echo " ============================================================== "

    name=ttylinux
    image=ttylinux-uec-amd64-12.1_2.6.35-22_1.img
    imageUploaded=false
    bundle_private=private
    bundle_public=public
    private_image=$bundle_private/$image.manifest.xml
    public_image=$bundle_public/$image.manifest.xml

    # image may not previously exist, so no need for it to be in trap
    echo "Sourcing Credentials Files: ${openrc_admin}"
    source ${openrc_admin};
    nova image-delete $private_image;
    nova image-delete $public_image;
    
    if [ ! -e "${image}" ]
    then
	echo "Tests:28-38 require image: ${image}"
	exit 1
    fi

    testNum=28
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${testNum} user: upload a new public image"
    echo "---------------------------------------------------------------------------"

    echo "Sourcing Credentials Files: ${openrc_demo1}"
    source ${openrc_demo1};
    euca-bundle-image -i $image
    euca-upload-bundle -b $bundle_public -m /tmp/$image.manifest.xml
    public_image_id=$(euca-register $bundle_public/$image.manifest.xml | cut -f2)
    echo XXXX public_image_id $public_image_id
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output


    if [ "$euca_describe_images_output" == "" ]; then
	msg="XXXX Test$testNum Failed to create image $public_image"
	echo "${msg}"
	write_log "${msg}" "${log}"
    else

	while true; do 
	    if [ "`euca-describe-images | grep $public_image_id | grep available`" != "" ]; then
		break
	    fi
        # wait till the image is available
	    sleep $sleepWait
	done

        #Make the images public
	euca-modify-image-attribute -l $public_image_id -a all
  
	euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
	echo euca_describe_images_output $euca_describe_images_output
	
	if [ "`glance image-show $public_image | grep is_public | grep True`" == "" ]; then
	    msg="XXXX Test$testNum Failed to create public image $public_image"
	    echo "${msg}"
	    write_log "${msg}" "${log}"
	else
	    msg="Step#${testNum} Successfully DONE"
	    echo "${msg}"
	    write_log "${msg}" "${log}"
	fi
	
    fi

    testNum=29
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${testNum} user: upload a new private image"
    echo "---------------------------------------------------------------------------"

    euca-bundle-image -i $image
    euca-upload-bundle -b $bundle_private -m /tmp/$image.manifest.xml
    private_image_id=$(euca-register $bundle_private/$image.manifest.xml | cut -f2)
    echo XXXX private_image_id $private_image_id
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    

    if [ "$euca_describe_images_output" == "" ]; then
	msg="XXXX Test$testNum Failed to create image $private_image"
	echo "${msg}"
	write_log "${msg}" "${log}"
    else
	
	while true; do 
	    if [ "`euca-describe-images | grep $private_image_id | grep available`" != "" ]; then
		break
	    fi
            # wait till the image is available
	    sleep $sleepWait
	done

        # Make the images public
        #euca-modify-image-attribute -l $private_image_id -a all

	euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
	echo euca_describe_images_output $euca_describe_images_output

	if [ "`glance image-show $private_image | grep is_public | grep False`" == "" ]; then
	    msg="XXXX Test$testNum Failed to create private image $private_image"
	else
	    msg="Step#${testNum} Successfully DONE"
	fi
	echo "${msg}"
	write_log "${msg}" "${log}"
    fi

    #echo "Sourcing ADMIN Credentials File: ${openrc_admin}"
    #source ${openrc_admin}
    
    testNum=34
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${testNum} user: make a private image public"
    echo "---------------------------------------------------------------------------"
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    

    if [ "`glance image-show $private_image | grep is_public | grep -i False`" ]; then 
	euca-modify-image-attribute -l $private_image_id -a all
	
	euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
	echo euca_describe_images_output $euca_describe_images_output
	
	if [ "`glance image-show $private_image | grep is_public | grep -i True`" ]; then
	    msg="Step#${testNum} Successfully DONE"
	else
	    msg="Step# ${testNum} Failed to change image is_public status"
	fi
	echo "${msg}"
	write_log "${msg}" "${log}"
    else
	msg="XXXX Test$testNum Failed because image is already public"
	echo "${msg}"
	write_log "${msg}" "${log}"
    fi

    testNum=35
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${testNum} user: make a public image private"
    echo "---------------------------------------------------------------------------"
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    if [ "`glance image-show $public_image | grep is_public | grep -i true`" ]; then 
	euca-modify-image-attribute -l $public_image_id -r all
	
	euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
	echo euca_describe_images_output $euca_describe_images_output
	
	if [ "`glance image-show $public_image | grep is_public | grep -i false`" ]; then
	    msg="Step#$testNum Successfully DONE"
	else
	    msg="Step#${testNum} Failed to change image is_public status"
	fi
	echo "${msg}"
	write_log "${msg}" "${log}"
    else
	msg="Step#${testNum} Failed because image is already private"
	echo "${msg}"
	write_log "${msg}" "${log}"
    fi

    echo 
    echo 
    
    testNum=36
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${testNum} user: make a public image to private image owned by another user (should fail)"
    echo "---------------------------------------------------------------------------"    

    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    echo "Sourcing Credentials Files: ${openrc_demo2}"
    source ${openrc_demo2}

    if [ "`glance image-show $private_image | grep is_public | grep -i true`" ]; then 
	euca-modify-image-attribute -l $private_image_id -r all
	
	euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
	echo euca_describe_images_output $euca_describe_images_output
	
	if [ "`glance image-show $private_image  | grep is_public | grep -i true`" ]; then
	    echo XXXX Test$testNum did not change image is_public status
	    msg="Step#${testNum} Successfully DONE"
	else
	    msg="Step#${testNum} FAILED - Changed the image is_public status for image owned by another user"
	fi
	echo "${msg}"
	write_log "${msg}" "${log}"
    else
	msg="Step#$testNum Failed because image is already private"
	echo "${msg}"
	write_log "${msg}" "${log}"
    fi
    

    testNum=37
    echo == Test $testNum user: delete an image 
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${testNum} user: delete an image"
    echo "---------------------------------------------------------------------------"
    
    echo "Sourcing Credentials Files: ${openrc_demo1}"
    source ${openrc_demo1}
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    euca-deregister $public_image_id
    if [ $? != 0 ]; then
	euca-delete-bundle -b public -p $image
    fi
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    if [[ $? -eq 0 && -z "`glance image-list | grep $public_image`" ]]; then
	msg="Step#${testNum} Successfully DONE"
    else
	msg="Step#${testNum} Failed to delete image $public_image"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"
    
    testNum=38

    echo "---------------------------------------------------------------------------"
    echo "Step#${testNum} user: delete an unauthorized image (should fail)"
    echo "---------------------------------------------------------------------------"
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    echo "Sourcing Credentials Files: ${openrc_demo2}"
    source ${openrc_demo2}
    euca-deregister $private_image_id
    if [ $? != 0 ]; then
	euca-delete-bundle -b private -p $image
    fi
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    if [ -z "`glance image-list | grep $private_image`" ]; then
        msg="Step#${testNum} Failed, should not be able to delete $private_image"
    else
	msg="Step#${testNum} Successfully DONE"
    fi
    echo "${msg}"
    write_log "${msg}" "${log}"

}
