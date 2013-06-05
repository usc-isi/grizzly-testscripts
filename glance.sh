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



clean_glance_repo() {

    echo "Cleaning all images and meta-data from glance repository"
    glance clear
}