
# Create a VPC
resource "aws_vpc" "terraform_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }
}

# Create an Internet Gateway for Public Subnet Internet Access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terraform_vpc.id
  tags = {
    Name = "InternetGateway"
  }
}

# Create public subnets
resource "aws_subnet" "public_subnet" {
  count = 3
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.terraform_vpc.cidr_block, 8, count.index)
  availability_zone = element(["eu-west-2a", "eu-west-2b", "eu-west-2c"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "private_subnet" {
  count = 3
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.terraform_vpc.cidr_block, 8, count.index + 3)
  availability_zone = element(["eu-west-2a", "eu-west-2b", "eu-west-2c"], count.index)
  tags = {
    Name = "PrivateSubnet-${count.index + 1}"
  }
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Create a NAT Gateway in one of the public subnets
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id # NAT Gateway in the first public subnet
  tags = {
    Name = "NatGateway"
  }
}

# Route Table for Public Subnets (to access the Internet)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.terraform_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Public Subnets with the Public Route Table
resource "aws_route_table_association" "public_association" {
  count    = 3
  subnet_id = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table for Private Subnets (to route traffic via NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.terraform_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "PrivateRouteTable"
  }
}

# Associate Private Subnets with the Private Route Table
resource "aws_route_table_association" "private_association" {
  count    = 3
  subnet_id = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Create a security group for Lambda
resource "aws_security_group" "lambda_security_group" {
  vpc_id = aws_vpc.terraform_vpc.id
  description = "Allow Lambda to access resources in the VPC"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "LambdaSecurityGroup"
  }
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.terraform_vpc.id
}

output "public_subnet_ids" {
  description = "Array of public subnets"
  value       = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  description = "Array of private subnets"
  value       = aws_subnet.private_subnet[*].id
}

output "lambda_security_group_id" {
  description = "Security Group ID for the Lambda function"
  value       = aws_security_group.lambda_security_group.id
}