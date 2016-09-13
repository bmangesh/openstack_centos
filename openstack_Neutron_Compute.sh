#! /bin/bash
#Autor : Mangeshkumar B Bharsakle
service_pass=openstack
source /root/requirment.sh
echo "
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
" > /etc/sysctl.conf

#Implement the changes:

sysctl -p

#To install the Networking components

yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch


#To configure the Networking common components

echo "
[DEFAULT]
rpc_backend = rabbit
auth_strategy = keystone 

core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

verbose = True
[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $service_pass

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $service_pass


" > /etc/neutron/neutron.conf


#To configure the Modular Layer 2 (ML2) plug-in

echo "
[ml2]
type_drivers = flat,vlan,gre,vxlan
tenant_network_types = gre
mechanism_drivers = openvswitch

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

[ovs]
local_ip = $Comp_IP

[agent]
tunnel_types = gre
" >  /etc/neutron/plugins/ml2/ml2_conf.ini



#Start the OVS service and configure it to start when the system boots:

systemctl enable openvswitch.service

systemctl start openvswitch.service

#To configure Compute to use Networking

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

cp /usr/lib/systemd/system/neutron-openvswitch-agent.service \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig



sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service

#Restart the Compute service:

systemctl restart openstack-nova-compute.service

#Start the Open vSwitch (OVS) agent and configure it to start when the system boots:

systemctl enable neutron-openvswitch-agent.service

systemctl start neutron-openvswitch-agent.service


