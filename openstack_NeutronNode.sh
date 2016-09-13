#! /bin/bash
#Autor : Mangeshkumar B Bharsakle
yum install epel-release -y

#Install the rdo-release-kilo package to enable the RDO repository:

yum install -y http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm

yum install -y openstack-selinux

yum install -y ntp

systemctl enable ntpd.service

systemctl start ntpd.service



source /root/requirment.sh
service_pass=openstack

echo "

net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0

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


echo "

[ml2]
type_drivers = flat,vlan,gre,vxlan
tenant_network_types = gre
mechanism_drivers = openvswitch

[ml2_type_flat]
flat_networks = external

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

[ovs]
local_ip = $NET_IP
bridge_mappings = external:br-ex

[agent]
tunnel_types = gre

" > /etc/neutron/plugins/ml2/ml2_conf.ini


echo "
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
external_network_bridge =
router_delete_namespaces = True

verbose = True

" > /etc/neutron/l3_agent.ini

echo "
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
dhcp_delete_namespaces = True
verbose = True
dnsmasq_config_file = /etc/neutron/dnsmasq-neutron.conf

" > /etc/neutron/dhcp_agent.ini

echo "
dhcp-option-force=26,1454
" > /etc/neutron/dnsmasq-neutron.conf

echo "
[DEFAULT]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_region = RegionOne
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $service_pass

nova_metadata_ip = controller

metadata_proxy_shared_secret = $service_pass

verbose = True

" > /etc/neutron/metadata_agent.ini

#To configure the Open vSwitch (OVS) service

#Start the OVS service and configure it to start when the system boots:

systemctl enable openvswitch.service

systemctl start openvswitch.service

#Add the external bridge:

ovs-vsctl add-br br-ex

#Add a port to the external bridge that connects to the physical external network interface:

ovs-vsctl add-port br-ex $INTERFACE_NAME

ethtool -K $INTERFACE_NAME gro off

#To finalize the installation

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

cp /usr/lib/systemd/system/neutron-openvswitch-agent.service \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig

sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service

#Start the Networking services and configure them to start when the system boots:

systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service \
  neutron-dhcp-agent.service neutron-metadata-agent.service \
  neutron-ovs-cleanup.service


systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service \
  neutron-dhcp-agent.service neutron-metadata-agent.service

