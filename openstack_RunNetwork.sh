#! /bin/bash
#Autor : Mangeshkumar B Bharsakle
source /root/requirment.sh
scp /root/requirment.sh $NET_IP:/root

scp /etc/hosts $NET_IP:/etc/hosts

scp /opt/Script/openstack_NeutronNode.sh $NET_IP:/root/openstack_NeutronNode.sh

ssh $NET_IP "sh /root/openstack_NeutronNode.sh"

