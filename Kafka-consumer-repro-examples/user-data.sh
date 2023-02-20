#!/bin/bash
export PATH=/usr/local/bin:$PATH;
yum update -y
amazon-linux-extras install docker -y
yum install docker
service docker start
usermod -a -G docker ec2-user
curl -L https://github.com/docker/compose/releases/download/1.7.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
chown root:docker /usr/local/bin/docker-compose

yum install -y git
git clone https://github.com/confluentinc/cp-all-in-one.git  /home/ec2-user/cp-all-in-one
chown -R ec2-user:ec2-user /home/ec2-user/cp-all-in-one
cd /home/ec2-user/cp-all-in-one/cp-all-in-one 
chown ec2-user:ec2-user docker-compose.yml
public_ip=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4)
KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://broker:29092,PLAINTEXT_HOST://${public_ip}:9092"
sed -i -E "s#KAFKA_ADVERTISED_LISTENERS:.*#KAFKA_ADVERTISED_LISTENERS: ${KAFKA_ADVERTISED_LISTENERS}#g" docker-compose.yml
/usr/local/bin/docker-compose -f ./docker-compose.yml up -d