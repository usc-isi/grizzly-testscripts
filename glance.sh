#!/bin/bash                                                                                                           

# glance.sh
#                                                                                                         
# Malek Musleh                                                                                                       
# mmusleh@isi.edu                                                                                                    
# May. 15, 2013                                                                                                      
#                                                                                                                    
# (c) 2013 USC/ISI                                                                                                   
#                                                                                                                    
# This script is provided for a reference only.                                                                      
# Its functional correctness is not guaranteed.                                                                      
# It contains helper functions related to volume usage in Openstack  



# Function to clear all images and meta-deta from glance repository
clean_glance_repo() {

    local cred_file=$1
    source $cred_file

    echo "Cleaning all images and meta-data from glance repository using credentials file: ${cred_file}"
    glance clear
}