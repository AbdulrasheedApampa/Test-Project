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
  description = "Allow inbound traffic for SSH, HTTP, HTTPS, Kubernetes, and etcd"
  vpc_id      = aws_vpc.rancher_vpc.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API Server
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd
  ingress {
    description = "etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Flannel Overlay Network (UDP)
  ingress {
    description = "Flannel Overlay Network"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubelet, Scheduler, Controller Manager
  ingress {
    description = "Kubelet, Scheduler, Controller Manager"
    from_port   = 10250
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
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

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get upgrade -y
              sudo apt-get remove docker docker-engine docker.io containerd runc -y
              sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
              sudo docker run -d --privileged \
              --restart=unless-stopped \
              -p 80:80 \
              -p 443:443 \
              --name rancher \
              rancher/rancher:latest
              EOF

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