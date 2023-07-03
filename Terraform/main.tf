terraform {
  backend "s3" {
    bucket = "project-2-mern-app-321"
    key = "global/mystatefile/terraform.tfstate"
    region = "us-east-1"
  }
  
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.100.0.0/16"

  tags = {
    Name = "my-vpc"
  }
}

#create s3
# resource "aws_s3_bucket" "mybucket" {
#   bucket = "project-2-mern-app-321"
#   tags = {
#     Name        = "My bucket"
#     Environment = "Dev"
#   }
#   lifecycle {
#     prevent_destroy = true
#   }
# }
  
# resource "aws_s3_bucket_acl" "acl" {
#   bucket = aws_s3_bucket.mybucket.id
#   acl    = "private"
# }

# resource "aws_s3_bucket_versioning" "versioning" {
#   bucket = aws_s3_bucket.mybucket.id
#   versioning_configuration {
#     status = "Enabled"
#   }  
# }





resource "aws_subnet" "private_subnet" {
  cidr_block        = "10.100.0.0/24"
  vpc_id     = aws_vpc.my_vpc.id
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.100.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet1"
  }

  
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.100.2.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet2"
  }
}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
 }
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}
# Create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  
}
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


# resource "aws_security_group" "lb_sg" {
#   name_prefix = "docker-nginx"
#   description = "My security group"
#   vpc_id     = aws_vpc.my_vpc.id

#   ingress {
#     description = "HTTPS"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["192.168.18.0/24"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "my_sg"
#   }
# }
# Create ALB
resource "aws_lb" "loadbalancer" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  tags = {
    environment = "dev"
  }
}

# Create target group
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

}
#  resource "aws_autoscaling_attachment" "demo_asg_attachment" { 
#    lb_target_group_arn    = aws_lb_target_group.my_target_group.arn 
#    autoscaling_group_name = aws_autoscaling_group.my_asg.id 

#  } 

# Create listener
resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.loadbalancer.arn

  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}
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

  owners = ["099720109477"] # Canonical
}
# creating launch configuration 
 resource "aws_launch_configuration" "project" { 
   image_id      = data.aws_ami.ubuntu.id
   instance_type   = "t2.micro" 
   security_groups    = [aws_security_group.allow_web.id,aws_security_group.allow_ssh.id,]
   user_data = filebase64("${path.module}/startup.sh")

  lifecycle {
    create_before_destroy = true
  }
}

# Define Auto Scaling Group
resource "aws_autoscaling_group" "my_asg" {
  name_prefix                 = "my-asg-"
  max_size                    = 2
  min_size                    = 1
  desired_capacity            = 2
  health_check_type           = "EC2"
  health_check_grace_period   = 300
  launch_configuration       = aws_launch_configuration.project.id
  target_group_arns          = [aws_lb_target_group.my_target_group.arn]
  vpc_zone_identifier         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tag {
    key                 = "Name"
    value               = "my-asg"
    propagate_at_launch = true
  }
}












# resource "aws" "instance1" {
#   ami = "ami-007855ac798b5175e"
#   instance_type = "t2.micro"
#   subnet_id = aws_subnet.public_subnet_1.id
#   security_groups = [aws_security_group.my_sg.id]
#   tags = {
#     Name = "my-instance-1"
#   }
# }

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow incoming web traffic"
  vpc_id = aws_vpc.my_vpc.id



  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow incoming SSH traffic"
  vpc_id = aws_vpc.my_vpc.id



  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
output "url" {
  value = "http://${aws_lb.loadbalancer.dns_name}/"
}

# #key-pair

#  resource "aws_key_pair" "app-key" {
#   key_name= "app-key" 
#   public_key = file("~/.ssh/app-key.ppk")

    
#  }