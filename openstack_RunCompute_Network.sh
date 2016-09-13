#! /bin/bash
#Autor : Mangeshkumar B Bharsakle
source /root/requirment.sh
scp /opt/Script/openstack_Neutron_Compute.sh $Comp_IP:/root/openstack_Neutron_Compute.sh

ssh $Comp_IP "sh /root/openstack_Neutron_Compute.sh"
