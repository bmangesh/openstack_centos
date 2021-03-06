#! /bin/bash
#Autor : Mangeshkumar B Bharsakle
# load service pass from config env
service_pass=openstack
# we create a quantum db irregardless of whether the user wants to install quantum
mysql -u root -popenstack <<EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$service_pass';
EOF

source /root/admin-openrc.sh

#Create the glance user:
openstack user create  glance --password openstack

#Add the admin role to the glance user and service project:
openstack role add --project service --user glance admin

#Create the glance service entity:
openstack service create --name glance --description "OpenStack Image service" image

#Create the Image service API endpoint:

 openstack endpoint create \
  --publicurl http://controller:9292 \
  --internalurl http://controller:9292 \
  --adminurl http://controller:9292 \
  --region RegionOne \
  image

#Install the Glance  packages:

yum install openstack-glance python-glance python-glanceclient -y 


echo "
[DEFAULT]
notification_driver = noop
verbose = True

[database]
connection = mysql://glance:$service_pass@controller/glance

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $service_pass
 
[paste_deploy]
flavor = keystone

[glance_store]
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
" > /etc/glance/glance-api.conf


echo "
[DEFAULT]
notification_driver = noop
verbose = True

[database]
connection = mysql://glance:$service_pass@controller/glance

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $service_pass

[paste_deploy]
flavor = keystone


" > /etc/glance/glance-registry.conf

#Populate the Image service database:
su -s /bin/sh -c "glance-manage db_sync" glance

systemctl enable openstack-glance-api.service openstack-glance-registry.service

systemctl start openstack-glance-api.service openstack-glance-registry.service

echo "export OS_IMAGE_API_VERSION=2" | tee -a /root/admin-openrc.sh 
