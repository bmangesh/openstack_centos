#! /bin/bash
#Autor : Mangeshkumar B Bharsakle
# load service pass from config env
service_pass=openstack
# we create a quantum db irregardless of whether the user wants to install quantum
mysql -u root -popenstack <<EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$service_pass';
EOF


source /root/admin-openrc.sh

source /root/requirment.sh

#Create the neutron user:
openstack user create neutron --password openstack

#Add the admin role to the neutron user:

openstack role add --project service --user neutron admin

#Create the neutron service entity:

openstack service create --name neutron \
  --description "OpenStack Networking" network

#Create the Networking service API endpoint:

openstack endpoint create \
  --publicurl http://controller:9696 \
  --adminurl http://controller:9696 \
  --internalurl http://controller:9696 \
  --region RegionOne \
  network


#Install Neutron Packages on controller Node

yum install -y openstack-neutron openstack-neutron-ml2 python-neutronclient which

echo "

[DEFAULT]
rpc_backend = rabbit
auth_strategy = keystone 

core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
nova_url = http://controller:8774/v2

verbose = True 

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $service_pass

[database]
connection = mysql://neutron:$service_pass@controller/neutron

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $service_pass

[nova]
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = nova
password = $service_pass




" > /etc/neutron/neutron.conf

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

" > /etc/neutron/plugins/ml2/ml2_conf.ini


#Nova neutron Configuration

echo "

[DEFAULT]
rpc_backend = rabbit
auth_strategy = keystone
verbose = True
my_ip = $Con_IP

vncserver_listen = $Con_IP
vncserver_proxyclient_address = $Con_IP

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[database]
connection = mysql://nova:$service_pass@controller/nova

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
username = nova
password = $service_pass

[glance]
host = controller

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[neutron]
url = http://controller:9696
auth_strategy = keystone
admin_auth_url = http://controller:35357/v2.0
admin_tenant_name = service
admin_username = neutron
admin_password = $service_pass

service_metadata_proxy = True
metadata_proxy_shared_secret = $service_pass 

" > /etc/nova/nova.conf


ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini


#Populate the database:

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

#Restart the Compute services:

 systemctl restart openstack-nova-api.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service

#Start the Networking service and configure it to start when the system boots:

systemctl enable neutron-server.service

systemctl start neutron-server.service
