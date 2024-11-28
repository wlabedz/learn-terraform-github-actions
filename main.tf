terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      }
  }
  
}

provider "aws" {
  region     = "us-east-1"
}



#creating a custom VPC defining its IP's range
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}


#creating an internet gateway for public internet access and associating it with created VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

#creating a route table for the VPC; adding default route to allow all traffic and direct it through the gateway
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "example"
  }
}


#creating a subnet within the VPC and defining its IP range
resource "aws_subnet" "sb" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  
  tags = {
    Name = "Main"
  }
}


#associating the subnet with the route table
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.sb.id
  route_table_id = aws_route_table.rt.id
}


#creating a security group for the vpc
resource "aws_security_group" "sg" {
  name        = "sg"
  description = "sg"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "sg"
  }
}


#adding an inbound rule allowing the HTTP traffic
resource "aws_vpc_security_group_ingress_rule" "sgi" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

#adding an outbound rule to allow all traffic
resource "aws_vpc_security_group_egress_rule" "sge" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" 
}


# creating a network interface, associating it with the subnet and security group and assigning it a private IP
resource "aws_network_interface" "ni" {
  subnet_id       = aws_subnet.sb.id
  private_ips     = ["10.0.1.50"]  
  security_groups = [aws_security_group.sg.id]
}


#allocating an elastic IP and associating it with the network interface
resource "aws_eip" "ei" {
  network_interface         = aws_network_interface.ni.id
  associate_with_private_ip = aws_network_interface.ni.private_ip

  depends_on = [aws_instance.web]
}


#the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}


#launching an EC2 Instance and associating it with the network interface
resource "aws_instance" "web" {
  count                     = 2
  ami                       = data.aws_ami.ubuntu.id
  instance_type             = "t2.micro"

  user_data = file("userdata.sh")

#a script to display a simple Hello World 

  network_interface{
    network_interface_id = aws_network_interface.ni.id
    device_index = 0
  }

  tags = {
    Name = "HelloWorld"
  }

}


#creating a load balancer
resource "aws_elb" "lb" {
  name               = "load-balancer"
  availability_zones = ["us-west-1b", "us-west-1e", "us-west-1f", "us-west-1d"]

  #defining how the load balancer listens for incoming traffic; it forwards traffic to 8000 using http protocol and listening on port 80
  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  #load balancer checks the status (health) of instances performing 2 health checks to consider instance healthy/unhealthy 
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  #instances attached to the load balancer
  instances = aws_instance.web.*.id

  #enabling cross zone load balancing
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "lb-load-balancer"
  }
}


#output the load balancer's DNS
output "elb_dns" {
  value = aws_elb.lb.dns_name
}


#output the public IP of the elastic IP
output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_eip.ei.public_ip
}

