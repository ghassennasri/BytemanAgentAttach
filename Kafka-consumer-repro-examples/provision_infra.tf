#Simple example provisionning an EC2 instance and installing
#
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region_name
  access_key = var.access_key
  secret_key = var.secret_key
  #region     = "eu-west-3"
}
data "aws_ssm_parameter" "webserver-ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
data "aws_vpc" "default_vpc"{
  default = true
}
data "aws_key_pair" "my-key" {
  key_name           = var.key_name
  #key_name           = "gnasri"
  include_public_key = true

}
#Create SG for allowing TCP/80 & TCP/22
resource "aws_security_group" "my_app_server_sg" {
  name        = "sg"
  description = "Allow TCP/29092 & TCP/22"
  vpc_id      = data.aws_vpc.default_vpc.id
  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow connect REST api"
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from TCP/80"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from 9021- ccc"
    from_port   = 9021
    to_port     = 9021
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "gnaConsumerPlayground" {
  ami           = data.aws_ssm_parameter.webserver-ami.value
  instance_type = "t2.large"
  key_name      = data.aws_key_pair.my-key.key_name
  security_groups = ["${aws_security_group.my_app_server_sg.name}"]
  associate_public_ip_address = true
  tags = {
    Name = "gnaConsumerPlayground"
  }

  root_block_device {
    volume_size = 50
  }

 
  user_data = "${file("./user-data.sh")}"
  depends_on = [aws_security_group.my_app_server_sg]
}
# Output the public IP address of the instance
output "public_ip" {
  value = aws_instance.gnaConsumerPlayground.public_ip
}