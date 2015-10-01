#!/bin/bash

set -e

sudo su <<HERE

# Setup our environment
chmod +x /home/centos/mapi-environment.sh
source /home/centos/mapi-environment.sh

## Install needed packages
export PATH=$PATH:/usr/local/bin:/sbin

yum update -y aws-cfn-bootstrap

yum install -y gcc-c++ make python-pp git openssl-devel wget

# Make sure the correct user owns the centos directory
chown -R centos /home/centos

cp cloudwatch-logs.ini /etc

cd ~
if [ -f awslogs-agent-setup.py ]; then
    rm awslogs-agent-setup.py
fi
wget https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
chmod +x ./awslogs-agent-setup.py
sudo ./awslogs-agent-setup.py -n -r us-west-2 -c /etc/cloudwatch-logs.ini


if [ -f /home/centos/aws.config ]; then
    rm /home/centos/aws.config
fi

HERE

##############################
# Install Kibana
##############################
# Create the nginx User
echo 'Creating nginx user'
# uid must be under 500 so it won't get deleted by Ops clean up script
sudo useradd -u 415 -s /sbin/nologin -m -d /var/lib/nginx -c 'Nginx web server' nginx

cd /opt/

sudo wget https://download.elastic.co/kibana/kibana/kibana-4.0.1-linux-x64.tar.gz

echo 'untar kibana'
sudo tar xf kibana-*.tar.gz

echo "rename kibana directory"
sudo mv kibana-*-linux-x64 kibana

echo 'changing host name'
sudo sed -i 's/host: "0.0.0.0"/host: "localhost"/g' /opt/kibana/config/kibana.yml

sudo su <<HERE
echo "adding kibana service to systemd"
cat >> /etc/systemd/system/kibana4.service << KIBANA
[Service]
ExecStart=/opt/kibana/bin/kibana
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=kibana4
User=root
Group=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
KIBANA

HERE

sudo systemctl enable kibana4


####################################
# End : Install Kibana
####################################

echo "Finished initializing instance."
exit 0
