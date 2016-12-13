# Add your VPC ID to default below
variable "vpc_id" {
  description = "VPC ID for usage throughout the build process"
  default = "vpc-a3a841c4"
}

variable "amis" {
    description = "AMI"
    default = "ami-5ec1673e" #Amazon Linux AMI 2016.09.0 HVM (SSD) EBS-Backed 64-bit
}

provider "aws" {
  region = "us-west-2"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"

}

#Create bastion instance
resource "aws_instance" "web" {
    ami = "${var.amis}"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    key_name = "cit360"
    vpc_security_group_ids = ["${aws_security_group.allow_to_22.id}"]
    subnet_id = "${aws_subnet.public_subnet_a.id}"
    tags {
        Name = "web"
    }
}

#Create a single Internet Gateway that will be placed in public route table for public subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = "${var.vpc_id}"

  tags = {
    Name = "gw"
  }
}

#Create Elastic IP to assign in NAT Gateway
resource "aws_eip" "eip" {
    vpc = true
    depends_on = ["aws_internet_gateway.gw"]
}


#Create a single NAT Gateway in any region that will be placed in the private route table for private subnets
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.eip.id}"
    subnet_id = "${aws_subnet.private_subnet_a.id}"
    depends_on = ["aws_internet_gateway.gw"]
}

#Create a public route table. This route table will have the Internet Gateway in the default route and will be used by the public subnets
resource "aws_route_table" "public_routing_table" {
  vpc_id = "${var.vpc_id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "public_routing_table"
  }
}

#Create a private route table. This route table will have the NAT Gateway in the default route and will be used by the private subnets.
resource "aws_route_table" "private_routing_table" {
    vpc_id = "${var.vpc_id}"

    tags {
        Name = "private_routing_table"
    }
}

#Part of private route table
resource "aws_route" "private_route" {
	route_table_id  = "${aws_route_table.private_routing_table.id}"
	destination_cidr_block = "0.0.0.0/0"
	nat_gateway_id = "${aws_nat_gateway.nat.id}"
}

#Create public subnet us-west-2a
resource "aws_subnet" "public_subnet_a" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.4.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2a"

    tags {
        Name = "public_a"
    }
}

#Create public subnet us-west-2b
resource "aws_subnet" "public_subnet_b" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.2.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2b"

    tags {
        Name = "public_b"
    }
}

#Create public subnet us-west-2c
resource "aws_subnet" "public_subnet_c" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.3.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2c"

    tags {
        Name = "public_c"
    }
}

#Create private subnet us-west-2a
resource "aws_subnet" "private_subnet_a" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.16.0/22"
    availability_zone = "us-west-2a"

    tags {
        Name = "private_a"
    }
}

#Create private subnet us-west-2b
resource "aws_subnet" "private_subnet_b" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.8.0/22"
    availability_zone = "us-west-2b"

    tags {
        Name = "private_a"
    }
}

#Create private subnet us-west-2c
resource "aws_subnet" "private_subnet_c" {
    vpc_id = "${var.vpc_id}"
    cidr_block = "172.31.12.0/22"
    availability_zone = "us-west-2c"

    tags {
        Name = "private_c"
    }
}

#Create a security group that allows access from your current public IP address to an instance on port 22 (SSH)
resource "aws_security_group" "allow_to_22" {
  name = "allow_to_22"
  description = "Allow all inbound traffic"

  ingress {
      from_port = 0
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["172.31.0.0/16"]
      cidr_blocks = ["172.88.22.64/32"]
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

}

#Create security group for DB
resource "aws_security_group" "db_security_group" {
  name = "db_security_group"
  description = "Security group for DB"

  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.31.0.0/16"]
  }

}

#Create a subnet group for DB 
resource "aws_db_subnet_group" "db_subnet_group" {
    name = "db_subnet_group"
    subnet_ids = ["${aws_subnet.private_subnet_a.id}", "${aws_subnet.private_subnet_b.id}"]
    tags {
        Name = "db_subnet_group"
    }
}

#Create a relational database service (RDS) instance
resource "aws_db_instance" "db_instance" {
    allocated_storage    = 5
    engine               = "mariadb"
    engine_version       = "10.0.24"
    instance_class       = "db.t2.micro"
    storage_type         = "gp2"
    name                 = "mariadb"
    identifier           = "mariadb"
    username             = "mrci18"
    password             = "${var.RDS_Key}"
    db_subnet_group_name = "${aws_db_subnet_group.db_subnet_group.id}"
}

#Create a security group with port 80 ingress and port 22 ingress from the cidr network of the VPC
resource "aws_security_group" "security_group_80_22" {
    name = "security_group_80_22"
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
resource "aws_security_group" "elb_security_group" {
    name = "elb_security_group"

    ingress {
        from_port = 0
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

#Create a new elastic load balancer (ELB)
resource "aws_elb" "elb" {
    name = "foobar-terraform-elb"
    subnets = ["${aws_subnet.public_subnet_b.id}", "${aws_subnet.public_subnet_c.id}"]
    security_groups = ["${aws_security_group.elb_security_group.id}"]

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
    
    instances = ["${aws_instance.webserver-b.id}", "${aws_instance.webserver-c.id}"]
    cross_zone_load_balancing = true
    idle_timeout = 60
    connection_draining = true
    connection_draining_timeout = 60

    tags {
      Name = "elb"
    }
}

#Create first instance that will run the web service
resource "aws_instance" "webserver-b" {
    ami = "${var.amis}"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.private_subnet_b.id}"
    vpc_security_group_ids = ["${aws_security_group.security_group_80_22.id}"]
    key_name = "cit360"
    tags {
        Name = "webserver-b"
        
        Service = "curriculum"
    }
}

#Create second instance that will run the web service
resource "aws_instance" "webserver-c" {
    ami = "${var.amis}"   
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.private_subnet_c.id}"
    vpc_security_group_ids = ["${aws_security_group.security_group_80_22.id}"]
    key_name = "cit360"
    tags {
        Name = "webserver-c"

        Service = "curriculum"
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
