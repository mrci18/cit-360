resource "aws_instance" "web" {
    ami = "${var.amis}"
    instance_type = "t2.micro"
    tags {
        Name = "TestInstance"
    }
}

#Configure the AWS provider
provider "aws" {
    region = "${var.aws_region}"
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
}

#Create VPC
resource "aws_vpc" "vpc_test" {
    cidr_block = "172.31.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "vpc_test"
    }
}

#Create Internet Gateway
resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.vpc_test.id}"

    tags {
      Name = "InternetGateWay"
    }
}

#Create EIP to assign in NAT Gateway
resource "aws_eip" "eip" {
    vpc = true
    depends_on = ["aws_internet_gateway.gw"]
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.eip.id}"
    subnet_id = "${aws_subnet.private_subnet_a.id}"
    depends_on = ["aws_internet_gateway.gw"]
}

#Create Public Routing Table
resource "aws_route_table" "public_routing_table" {
    vpc_id = "${aws_vpc.vpc_test.id}"
    route {
        cidr_block = "10.31.0.0/24"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }

    tags {
        Name = "public_routing_table"
  }
}

#Create A Private Route Table

resource "aws_route_table" "private_routing_table" {
    vpc_id = "${aws_vpc.vpc_test.id}"
  
    tags {
        Name = "private_routing_table"
  }
}

#This route table will have the NAT Gateway in the default route and will be used by the private subnets.

resource "aws_route" "private" {
    route_table_id = "${aws_route_table.private_routing_table.id}"
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
}

#Create public subnet us-west-2a
resource "aws_subnet" "public_subnet_a" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.0.1/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2a"

    tags {
        Name = "public_a"
    }
}

#Create public subnet us-west-2b
resource "aws_subnet" "public_subnet_b" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.1.2/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2b"

    tags {
        Name = "public_b"
    }
}

#Create public subnet us-west-2c
resource "aws_subnet" "public_subnet_c" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.1.3/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2c"

    tags {
        Name = "public_c"
    }
}

#Create private subnet us-west-2a
#Public subnets should /22 inside VPR CIDR space
#Private subnet uses NAT Gateway in its routing table for the default route
resource "aws_subnet" "private_subnet_a" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.4.1/22"
    availability_zone = "us-west-2a"

    tags {
        Name = "private_a"
    }
}

#Create private subnet us-west-2b
resource "aws_subnet" "private_subnet_b" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.4.2/22"
    availability_zone = "us-west-2b"

    tags {
        Name = "private_b"
    }
}

#Create private subnet us-west-2c
resource "aws_subnet" "private_subnet_c" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.4.3/22"
    availability_zone = "us-west-2c"

    tags {
        Name = "private_c"
    }
}

#Create Security Group that allows access from current public IP address to an instance on port22 (SSH)
resource "aws_security_group" "allow_all" {
    name = "allow_all"
    description = "Allow access from current public IP address to an instance on port22 (SSH)"

    ingress {
        from_port = 0
        to_port = 22
        protocol = "-1"
    }

    tags {
        Name = "allow_all"
    }
}


