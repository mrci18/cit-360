#VPC ID to default below
variable "vpc_id" {
    description = "VPC ID for usage throughout the build process"
    default = "vpc-a3a841c4"
}

#AWS Region default
variable "aws_region" {
    description = "EC2 Region for the VPC"
    default = "us-west-2"
}

#AMI default 
variable "amis" {
    description = "AMI"
    default = "ami-5ec1673e" #Amazon Linux AMI 2016.09.0 HVM (SSD) EBS-Backed 64-bit
}

#Create instance
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
        cidr_block = "10.31.1.0/24"
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
    vpc_id = "${aws_vpc.vpc_test.id}"
    cidr_block = "172.31.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2a"

    tags {
        Name = "public_a"
    }
}

#Create public subnet us-west-2b
resource "aws_subnet" "public_subnet_b" {
    vpc_id = "${aws_vpc.vpc_test.id}"
    cidr_block = "172.31.2.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2b"

    tags {
        Name = "public_b"
    }
}

#Create public subnet us-west-2c
resource "aws_subnet" "public_subnet_c" {
    vpc_id = "${aws_vpc.vpc_test.id}"
    cidr_block = "172.31.3.0/24"
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
    vpc_id = "${aws_vpc.vpc_test.id}"
    cidr_block = "172.31.5.0/22"
    availability_zone = "us-west-2a"

    tags {
        Name = "private_a"
    }
}

#Create private subnet us-west-2b
resource "aws_subnet" "private_subnet_b" {
    vpc_id = "${aws_vpc.vpc_test.id}"
    cidr_block = "172.31.8.0/22"
    availability_zone = "us-west-2b"

    tags {
        Name = "private_b"
    }
}

#Create private subnet us-west-2c
resource "aws_subnet" "private_subnet_c" {
    vpc_id = "${aws_vpc.vpc_test.id}"
    cidr_block = "172.31.12.0/22"
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
        protocol = "tcp"
	cidr_blocks = [
		"172.31.0.0/16",
	]
    }

    tags {
        Name = "allow_all"
    }
}

#Assciate public_a to public route table
resource "aws_route_table_association" "public_subnet_a_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_a.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}

#Assciate public_b to public route table
resource "aws_route_table_association" "public_subnet_b_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_b.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}

#Assciate public_c to public route table
resource "aws_route_table_association" "public_subnet_c_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_c.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}

#Assciate private_a to private route table
resource "aws_route_table_association" "private_subnet_a_rt_assoc" {
    subnet_id = "${aws_subnet.private_subnet_a.id}"
    route_table_id = "${aws_route_table.private_routing_table.id}"
}

#Assciate private_b to private route table
resource "aws_route_table_association" "private_subnet_b_rt_assoc" {
    subnet_id = "${aws_subnet.private_subnet_b.id}"
    route_table_id = "${aws_route_table.private_routing_table.id}"
}

#Assciate private_c to private route table
resource "aws_route_table_association" "private_subnet_c_rt_assoc" {
    subnet_id = "${aws_subnet.private_subnet_c.id}"
    route_table_id = "${aws_route_table.private_routing_table.id}"
}

#Create DB subnet group
resource "aws_db_subnet_group" "default" {
    name = "main"
    subnet_ids = ["${aws_subnet.private_subnet_a.id}", "${aws_subnet.private_subnet_b.id}"]
    tags {
        Name = "My DB subnet group"
    }
}

#Create a relational database service (RDS) instance
resource "aws_db_instance" "default" {
    allocated_storage    = 5
    engine               = "mariadb"
    engine_version       = "10.0.24"
    instance_class       = "db.t2.micro"
    multi_az             = "No"  
    storage_type         = "gp2"
    name                 = "mariadb"
    username             = "mrci18"
    password             = "${var.RDS_Key}"
    db_subnet_group_name = "my_database_subnet_group"
    parameter_group_name = "default.mariadb10"
}

#Create a security group with port 80 ingress and port 22 ingress from the cidr network of the VPC
resource "aws_security_group" "allow_all" {
    name = "allow_all"
    description = "Allow all inbound traffic"

    ingress {
        from_port = 0
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["172.31.0.0/16"]
    }

    ingress {
        from_port = 0
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["172.31.0.0/16"]
    }

}

#Create a new security group for the ELB
resource "aws_security_group" "allow_all" {
    name = "allow_all"
    description = "Allow all inbound traffic"

    ingress {
        from_port = 0
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

#Create a new load balancer
resource "aws_elb" "bar" {
    name = "foobar-terraform-elb"
    availability_zones = ["us-west-2b", "us-west-2c"]

    access_logs {
      bucket = "foo"
      bucket_prefix = "bar"
      interval = 60
    }

    listener {
      instance_port = 80
      instance_protocol = "http"
      lb_port = 80
      lb_protocol = "http"
    }

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 5
      target = "HTTP:80/"
      interval = 30
    }

    instances = ["${aws_instance.foo.id}"]
    cross_zone_load_balancing = true
    idle_timeout = 60
    connection_draining = true
    connection_draining_timeout = 60

    tags {
      Name = "elb"
    }
}

#Create first instance that will run the web service
resource "aws_instance" "web1" {
    ami = "${var.amis}"
    instance_type = "t2.micro"
    tags {
        Name = "webserver-b"
        
        Service = "curriculum"
    }
}

#Create second instance that will run the web service
resource "aws_instance" "web" {
    ami = "${var.amis}"
    instance_type = "t2.micro"
    tags {
        Name = "webserver-c"

        Service = "curriculum"
    }
}


















