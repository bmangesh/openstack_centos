#! /bin/bash

yum install epel-release -y

#Install the rdo-release-kilo package to enable the RDO repository:

yum install -y http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm 

yum install -y openstack-selinux 

yum install -y ntp 

systemctl enable ntpd.service

systemctl start ntpd.service

#Install Compute-Node Packages

yum install openstack-nova-compute sysfsutils -y

service_pass=openstack

source /root/requirment.sh

echo "
[DEFAULT]
rpc_backend = rabbit
auth_strategy = keystone 
my_ip = $Comp_IP

verbose = True

vnc_enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $Comp_IP
novncproxy_base_url = http://controller:6080/vnc_auto.html

# Network Configuration

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver


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

" > /etc/nova/nova.conf

var=`egrep -c '(vmx|svm)' /proc/cpuinfo`


if [  $var -eq 0 ]; then
echo '
[libvirt]
virt_type = qemu
     ' >> /etc/nova/nova.conf
  fi

systemctl enable libvirtd.service openstack-nova-compute.service

systemctl restart libvirtd.service openstack-nova-compute.service

