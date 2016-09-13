#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You need to be 'root' dude." 1>&2
   exit 1
fi


# throw in a few other services we need installed
yum install mariadb mariadb-server MySQL-python -y >> /dev/null

yum install epel-release -y >> /dev/null

yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y >> /dev/null
# now let's install MySQL

# make mysql listen on 0.0.0.0

# setup mysql to support utf8 and innodb

#/etc/my.cnf.d/mariadb_openstack.cnf
echo "
[mysqld]
bind-address = 0.0.0.0
default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8
" >> /etc/my.cnf.d/mariadb_openstack.cnf

# restart
systemctl start mariadb.service
# wait for restart
sleep 4 

# secure mysql
mysqladmin -u root password openstack

#Install Rabbitmq-server 

yum install rabbitmq-server -y >> /dev/null

sleep 50
systemctl restart rabbitmq-server.service 

#Add the openstack user to rabbitMQ

rabbitmqctl add_user openstack openstack

#Permit configuration, write, and read access for the openstack user:

rabbitmqctl set_permissions openstack ".*" ".*" ".*"

