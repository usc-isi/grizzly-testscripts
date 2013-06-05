#!/bin/bash


source functions.sh
source volume.sh


function tests_28_to_38() {

    #source openrc-root-cperi
    local log=$1
    local openrc_admin=$2

    echo " ============================================================== "
    echo " ================ Starting Tests 28-38 ======================== "
    echo " ============================================================== "

    timeoutWait=60
    sleepWait=5
    name=cirros-0.3.1
    image=cirros-0.3.1-x86_64-disk.img
    image_url=http://download.cirros-cloud.net/0.3.1/$image
    imageUploaded=false
    bundle_private=private
    bundle_public=public
    private_image=$bundle_private/$image.manifest.xml
    public_image=$bundle_public/$image.manifest.xml


    trap "{
    source openrc-root-cperi;
    nova image-delete $private_image;
    nova image-delete $public_image;
}" EXIT
    

    testNum=28
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${$testNum} user: upload a new public image"
    echo "---------------------------------------------------------------------------"
    
    euca-bundle-image -i $image
    euca-upload-bundle -b $bundle_public -m /tmp/$image.manifest.xml
    public_image_id=$(euca-register $bundle_public/$image.manifest.xml | cut -f2)
    echo XXXX public_image_id $public_image_id
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output


    if [ "$euca_describe_images_output" == "" ]; then
	echo XXXX Test$testNum Failed to create image $public_image
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
	    echo XXXX Test$testNum Failed to create public image $public_image
	else
	    echo == Test$testNum OK
	fi
	
    fi

    testNum=29
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${$testNum} user: upload a new private image"
    echo "---------------------------------------------------------------------------"

    euca-bundle-image -i $image
    euca-upload-bundle -b $bundle_private -m /tmp/$image.manifest.xml
    private_image_id=$(euca-register $bundle_private/$image.manifest.xml | cut -f2)
    echo XXXX private_image_id $private_image_id
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    

    if [ "$euca_describe_images_output" == "" ]; then
	echo XXXX Test$testNum Failed to create image $private_image
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
	    echo XXXX Test$testNum Failed to create private image $private_image
	else
	    echo == Test$testNum OK
	fi

    fi


    source openrc-root-cperi
    
    testNum=34
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${$testNum} user: make a private image public"
    echo "---------------------------------------------------------------------------"
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    

    if [ "`glance image-show $private_image | grep is_public | grep -i False`" ]; then 
	euca-modify-image-attribute -l $private_image_id -a all
	
	euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
	echo euca_describe_images_output $euca_describe_images_output
	
	if [ "`glance image-show $private_image | grep is_public | grep -i True`" ]; then
	    echo == Test$testNum OK
	else
	    echo === Failed to change image is_public status
	fi
    else
	echo XXXX Test$testNum Failed because image is already public
    fi


    testNum=35
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${$testNum} user: make a public image private"
    echo "---------------------------------------------------------------------------"
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    if [ "`glance image-show $public_image | grep is_public | grep -i true`" ]; then 
	euca-modify-image-attribute -l $public_image_id -r all
	
	euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
	echo euca_describe_images_output $euca_describe_images_output
	
	if [ "`glance image-show $public_image | grep is_public | grep -i false`" ]; then
	    echo == Test$testNum OK
	else
	    echo XXXX Test$testNum Failed to change image is_public status
	fi
    else
	echo XXXX Test$testNum Failed because image is already private
    fi

    echo 
    echo 
    
    testNum=36
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${$testNum} user: make a public image to private image owned by another user (should fail)"
    echo "---------------------------------------------------------------------------"    


    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    
    source openrc-demo2
    if [ "`glance image-show $private_image | grep is_public | grep -i true`" ]; then 
	euca-modify-image-attribute -l $private_image_id -r all
	
	euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
	echo euca_describe_images_output $euca_describe_images_output
	
	if [ "`glance image-show $private_image  | grep is_public | grep -i true`" ]; then
	    echo XXXX Test$testNum did not change image is_public status
	    echo == Test$testNum OK
	else
	    echo XXXX Test$testNum FAILED - Changed the image is_public status for image owned by another user
	fi
    else
	echo XXXX Test$testNum Failed because image is already private
    fi
    

    testNum=37
    echo == Test $testNum user: delete an image 
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Step#${$testNum} user: delete an image"
    echo "---------------------------------------------------------------------------"
    
    source openrc-root-cperi
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    
    euca-deregister $public_image_id
    if [ $? != 0 ]; then
	euca-delete-bundle -b public -p $image
    fi
    
    euca_describe_images_output=$(euca-describe-images | grep $public_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    if [[ $? -eq 0 && -z "`glance image-list | grep $public_image`" ]]; then
	echo == Test$testNum OK
    else
	echo XXXX Test$testNum Failed to delete image $public_image
    fi
    
    
    testNum=38

    echo "---------------------------------------------------------------------------"
    echo "Step#${$testNum} user: delete an unauthorized image (should fail)"
    echo "---------------------------------------------------------------------------"
    source openrc-demo2
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    euca-deregister $private_image_id
    if [ $? != 0 ]; then
	euca-delete-bundle -b private -p $image
    fi
    
    euca_describe_images_output=$(euca-describe-images | grep $private_image_id)
    echo euca_describe_images_output $euca_describe_images_output
    
    if [ -z "`glance image-list | grep $private_image`" ]; then
	echo XXXX Test$testNum Failed, should not be able to delete $private_image
    else
	echo == Test$testNum OK
    fi
    
    # clean up
    echo 
    echo 
    echo TEST COMPLETED - CLEANUP
    echo 
    
    nova image-delete $private_image
    nova image-delete $public_image

    echo

}