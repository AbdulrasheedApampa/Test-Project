# module "terraform_state" {
#   source      = "./modules/terraform-state"
#   bucket_name = "rasheed-tp-bk"
#   table_name  = "my-dynamodb-table"
# }

# Terraform configuration for backend state storage
terraform {
  backend "s3" {
    bucket         = "rasheed-tp-bk"
    key            = "terraform.tfstate"  
    region         = "us-east-1"
    dynamodb_table = "my-dynamodb-table"
    encrypt        = true
  }
}

# Fetch the latest Ubuntu 20.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create the VPC
resource "aws_vpc" "rancher_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "RancherVPC"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.rancher_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.rancher_vpc.id
  tags = {
    Name = "InternetGateway"
  }
}

# Create a public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.rancher_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a security group for Rancher
resource "aws_security_group" "rancher_sg" {
  name        = "rancher_sg"
  description = "Allow inbound traffic on ports 22, 80, 8080, and 443"
  vpc_id      = aws_vpc.rancher_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    description = "HTTP Alternate"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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

# Create the Rancher instance
resource "aws_instance" "rancher_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  # availability_zone  = "us-east-1b"
  key_name               = "rancher-key-pair"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.rancher_sg.id]
  tags = {
    Name = "Rancher-Instance"
  }

  # user_data = <<-EOF
  #             #!/bin/bash
  #             sudo apt-get update -y
  #             sudo apt-get install -y docker.io
  #             sudo systemctl start docker
  #             sudo systemctl enable docker
  #             sudo usermod -aG docker ubuntu
  #             sudo docker run -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher
  #             EOF

  depends_on = [aws_route_table_association.public_rt_assoc]
}

# Create a general-purpose instance
resource "aws_instance" "general_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  # availability_zone  = "us-east-1b"
  key_name               = "rancher-key-pair"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.rancher_sg.id]
  tags = {
    Name = "General-Instance"
  }

  depends_on = [aws_route_table_association.public_rt_assoc]
}

# Output the public IPs of the instances
output "rancher_instance_public_ip" {
  value = aws_instance.rancher_vm.public_ip
}

output "general_instance_public_ip" {
  value = aws_instance.general_vm.public_ip
}