terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

resource "aws_vpc" "MyBlog" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyBlog"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.MyBlog.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.MyBlog.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.MyBlog.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id     = aws_vpc.MyBlog.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "${var.region}b"
  tags = {
    Name = "private-subnet-2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.MyBlog.id

  tags = {
    Name = "MyBlog-gw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.MyBlog.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "MyBlog-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.MyBlog.id

  tags = {
    Name = "MyBlog-private-rt"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

module "fck-nat" {
  source = "git::https://github.com/RaJiska/terraform-aws-fck-nat.git"

  name                 = "MyBlog-nat"
  vpc_id               = aws_vpc.MyBlog.id
  subnet_id            = aws_subnet.public_1.id
  instance_type        = var.instance_type            
  ha_mode              = true                 
  use_cloudwatch_agent = true                 

  update_route_tables = true
  route_tables_ids = {
    "private_rt" = aws_route_table.private_rt.id
  }
}

resource "aws_security_group" "alb_sg" {
  name = "MyBlog-alb-sg"
  vpc_id = aws_vpc.MyBlog.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "MyBlog-alb-sg"
  }
}

resource "aws_security_group" "web_sg" {
  name = "MyBlog-web-sg"
  vpc_id = aws_vpc.MyBlog.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "MyBlog-web-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name = "MyBlog-rds-sg"
  vpc_id = aws_vpc.MyBlog.id
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "MyBlog-rds-sg"
  }
}