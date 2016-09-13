#! /bin/bash
#Autor : Mangeshkumar B Bharsakle
source /root/requirment.sh
scp /root/requirment.sh $Comp_IP:/root

scp /etc/hosts $Comp_IP:/etc/hosts

scp /opt/Script/openstack_ComputeNode.sh $Comp_IP:/root/openstack_ComputeNode.sh

ssh $Comp_IP "sh /root/openstack_ComputeNode.sh" 
