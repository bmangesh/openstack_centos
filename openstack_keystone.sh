#! /bin/bash


# load service pass from config env
service_pass=openstack
# we create a quantum db irregardless of whether the user wants to install quantum
mysql -u root -popenstack <<EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$service_pass';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$service_pass';
EOF

token=`cat /dev/urandom | head -c2048 | md5sum | cut -d' ' -f1`

yum install -y openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached 

systemctl enable memcached.service

systemctl start memcached.service


echo "
[DEFAULT]
admin_token =$token
verbose = True
[database]
connection = mysql://keystone:openstack@controller/keystone

[memcache]
servers = localhost:11211

[token]
provider = keystone.token.providers.uuid.Provider
driver = keystone.token.persistence.backends.memcache.Token

[revoke]
driver = keystone.contrib.revoke.backends.sql.Revoke

" > /etc/keystone/keystone.conf

su -s /bin/sh -c "keystone-manage db_sync" keystone


#To configure the Apache HTTP server

sed -i  's/^#ServerName www.example.com:80/ServerName controller/g' /etc/httpd/conf/httpd.conf

echo '

Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /var/www/cgi-bin/keystone/main
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LogLevel info
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /var/www/cgi-bin/keystone/admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LogLevel info
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined
</VirtualHost>
' > /etc/httpd/conf.d/wsgi-keystone.conf

mkdir -p /var/www/cgi-bin/keystone

echo "
import os

from keystone.server import wsgi as wsgi_server


name = os.path.basename(__file__)

# NOTE(ldbragst): 'application' is required in this context by WSGI spec.
# The following is a reference to Python Paste Deploy documentation
# http://pythonpaste.org/deploy/
application = wsgi_server.initialize_application(name)


" > /var/www/cgi-bin/keystone/main

cp /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin

chown -R keystone:keystone /var/www/cgi-bin/keystone

chmod 755 /var/www/cgi-bin/keystone/*

systemctl enable httpd.service

systemctl start httpd.service

#Create admin-openrc.sh

cat > /root/admin-openrc.sh <<EOF
# set up env variables for install
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_TOKEN=$token
export OS_URL=http://controller:35357/v2.0
export OS_AUTH_URL=http://controller:35357/v3
EOF
