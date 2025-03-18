terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

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
  use_cloudwatch_agent = true                 
  ha_mode = false
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

resource "aws_s3_bucket" "myblog_assets" {
  bucket = "karams-myblog-assets"
  force_destroy = true
  tags = {
    Name = "MyBlog-Assets"
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "MyBlog-ec2-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }
    ]
  })
}


resource "aws_iam_role_policy" "ec2_s3_role_policy" {
  name = "MyBlog-ec2-s3-role-policy"
  role = aws_iam_role.ec2_s3_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.myblog_assets.arn, "${aws_s3_bucket.myblog_assets.arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "MyBlog-ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

locals {
  index_html_content = <<EOF
                        <!DOCTYPE html>
                        <html>
                        <head>
                            <title>My Blog</title>
                            <style>body { font-family: Arial; margin: 40px; } header { background: #333; color: white; padding: 10px; text-align: center; }</style>
                        </head>
                        <body>
                            <header><h1>Welcome to My Blog</h1></header>
                            <div><h2>First Post</h2><p>My Blog Project - I created this project to showcase and highlight my ability to create and maintain multiple AWS services using infrastructure as code with Terraform. I was able to create a sample blog by using EC2 instances, RDS, S3, and VPC components. I followed security best practices while setting up my VPC with keeping important components behind private subnets. I also made sure my solution was highly reliable and available. For more detailed information, please check out my GitHub Repository.</p></div>
                        </body>
                        </html>
                        EOF
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.myblog_assets.bucket
  key          = "index.html"
  content      = local.index_html_content
  content_type = "text/html"
  acl          = "private"
}

resource "aws_db_subnet_group" "myblog_db_subnet" {
  name = "myblog-db-subnet"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]  
}

resource "aws_db_instance" "myblog_db" {
  identifier = "myblog-db"
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  username = var.db_username
  password = var.db_password
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.myblog_db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  tags = {
    Name = "MyBlog-db"
  }
}

locals {
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl start nginx
              systemctl enable nginx
              yum install -y mysql awscli amazon-ssm-agent
              systemctl start amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              aws s3 cp s3://${aws_s3_bucket.myblog_assets.bucket}/index.html /usr/share/nginx/html/index.html
              rds_host=$(echo "${aws_db_instance.myblog_db.endpoint}" | sed 's/:3306//')
              rds_version=$(mysql -h $rds_host -u ${var.db_username} -p${var.db_password} -e "SELECT @@version;" -B --silent)
              echo "<p>RDS Endpoint: ${aws_db_instance.myblog_db.endpoint}</p>" >> /usr/share/nginx/html/index.html
              echo "<p>RDS Version: $rds_version</p>" >> /usr/share/nginx/html/index.html            
              systemctl restart nginx
              EOF
}

resource "aws_launch_template" "myblog_web" {
  name = "MyBlog-web"
  image_id = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_s3_profile.arn
  }
  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.web_sg.id]
  }
  user_data = base64encode(local.user_data)
  update_default_version = true
  instance_initiated_shutdown_behavior = "terminate"
}

resource "aws_autoscaling_group" "myblog_web_asg" {
  name = "MyBlog-web-asg"
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  desired_capacity = 2
  max_size = 4
  min_size = 2
  default_cooldown = 30
  force_delete = true
  target_group_arns = [aws_lb_target_group.myblog_tg.arn]
  launch_template {
    id = aws_launch_template.myblog_web.id
    version = "$Latest"
  }
  tag {
    key = "Name"
    value = "MyBlog-web"
    propagate_at_launch = true
  }
}

resource "aws_lb" "myblog_alb" {
  name = "MyBlog-alb"
  internal = false
  load_balancer_type = "application"
  subnets = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups = [aws_security_group.alb_sg.id]
  tags = {
    Name = "MyBlog-alb"
  }
}

resource "aws_lb_target_group" "myblog_tg" {
  name = "MyBlog-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.MyBlog.id
  health_check { path = "/" }
  tags = {
    Name = "MyBlog-tg"
  }
}

resource "aws_lb_listener" "myblog_listener" {
  load_balancer_arn = aws_lb.myblog_alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.myblog_tg.arn
  }
}
