resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

#Retrieve AZs available for the current region
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "subnet-1"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "subnet-2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "route_table"
  }
}

resource "aws_route_table_association" "subnet-1" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "subnet-2" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "alb_sg" {
  name        = "ALB_sg"
  vpc_id      = aws_vpc.main.id
  # Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon2" {
  most_recent = true

  filter {
    name = "name"
    values = ["amzn2-ami-*-hvm-*-arm64-gp2"]
  }

  filter {
    name = "architecture"
    values = ["arm64"]
  }

  owners = ["amazon"]
}

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"
  image_id = aws_ami.amazon2.image_id
  instance_type = "t2.micro"
  key_name = "test"
  security_groups = [ aws_security_group.alb_sg ]
  associate_public_ip_address = true
  lifecycle {
      create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "asg"
  max_size                  = 2
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = aws_launch_configuration.web.name
  vpc_zone_identifier       = [aws_subnet.example1.id, aws_subnet.example2.id]

  timeouts {
    delete = "15m"
  }

}

resource "aws_lb" "test-alb" {
  name               = "test-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]

  enable_deletion_protection = true

  tags = {
    Environment = "test"
  }
}