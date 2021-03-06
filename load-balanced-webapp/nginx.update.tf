variable "x_aws_access_key" {}

variable "x_aws_secret_key" {}

variable "x_network_address_space" {
  default = "10.10.0.0/16"
}

variable "x_subnet_1_address_space" {
  default = "10.10.0.0/24"
}

variable "x_subnet_2_address_space" {
  default = "10.10.1.0/24"
}

variable "x_key_name" {
  default = "PluralsightKeys"
}

variable "x_private_key_path" {}

data "aws_availability_zones" "available" {}

provider "aws" {
  access_key = "${var.x_aws_access_key}"
  secret_key = "${var.x_aws_secret_key}"
  region = "ap-southeast-1"
}

resource "aws_vpc" "wa-vpc" {
  cidr_block = "${var.x_network_address_space}"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "wa-internet-gateway" {
  vpc_id = "${aws_vpc.wa-vpc.id}"
}

resource "aws_subnet" "wa-subnet-1" {
  cidr_block = "${var.x_subnet_1_address_space}"
  vpc_id = "${aws_vpc.wa-vpc.id}"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "wa-subnet-2" {
  cidr_block = "${var.x_subnet_2_address_space}"
  vpc_id = "${aws_vpc.wa-vpc.id}"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_route_table" "wa-route-table" {
  vpc_id = "${aws_vpc.wa-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.wa-internet-gateway.id}"
  }
}

resource "aws_route_table_association" "wa-route-table-association-subnet-1" {
  route_table_id = "${aws_route_table.wa-route-table.id}"
  subnet_id = "${aws_subnet.wa-subnet-1.id}"
}

resource "aws_route_table_association" "wa-route-table-association-subnet-2" {
  route_table_id = "${aws_route_table.wa-route-table.id}"
  subnet_id = "${aws_subnet.wa-subnet-2.id}"
}

resource "aws_security_group" "wa-security-group-elb" {
  name = "wa-security-group-elb"
  vpc_id = "${aws_vpc.wa-vpc.id}"
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

resource "aws_security_group" "wa-security-group" {
  name = "wa-security-group"
  vpc_id = "${aws_vpc.wa-vpc.id}"
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = [
      "${var.x_network_address_space}"]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

resource "aws_elb" "wa-load-balancer" {
  name = "wa-load-balancer"
  security_groups = [
    "${aws_security_group.wa-security-group-elb.id}"]
  subnets = [
    "${aws_subnet.wa-subnet-1.id}",
    "${aws_subnet.wa-subnet-2.id}"]
  instances = [
    "${aws_instance.wa-nginx1.id}",
    "${aws_instance.wa-nginx2.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
}

resource "aws_instance" "wa-nginx1" {
  ami = "ami-01da99628f381e50a"
  instance_type = "t2.micro"
  key_name = "${var.x_key_name}"
  subnet_id = "${aws_subnet.wa-subnet-1.id}"
  vpc_security_group_ids = [
    "${aws_security_group.wa-security-group.id}"]

  connection {
    user = "ec2-user"
    private_key = "${file(var.x_private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install nginx1.12 -y",
      "sudo service nginx start",
      "echo '<html><head><title>Blue Team Server</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Blue Team</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
}

resource "aws_instance" "wa-nginx2" {
  ami = "ami-01da99628f381e50a"
  instance_type = "t2.micro"
  key_name = "${var.x_key_name}"
  subnet_id = "${aws_subnet.wa-subnet-2.id}"
  vpc_security_group_ids = [
    "${aws_security_group.wa-security-group.id}"]

  connection {
    user = "ec2-user"
    private_key = "${file(var.x_private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install nginx1.12 -y",
      "sudo service nginx start",
      "echo '<html><head><title>Green Team Server</title></head><body style=\"background-color:#77A032\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Green Team</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
}

output "aws_elb_public_dns" {
  value = "${aws_elb.wa-load-balancer.dns_name}"
}



