terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.36.0"
    }
  }
}

locals {
  envs = { for tuple in regexall("(.*)=(.*)", file("../.env")) : tuple[0] => sensitive(tuple[1]) }
}

provider "aws" {
  access_key = local.envs["AWS_ACCESS_KEY_ID"]
  secret_key = local.envs["AWS_SECRET_ACCESS_KEY"]
  region = local.envs["AWS_REGION"]
}

resource "aws_vpc" "complicate_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "complicate_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.complicate_vpc.id
  availability_zone = "ap-northeast-2a"
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.complicate_vpc.id
  availability_zone = "ap-northeast-2a"
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "private_subnet"
  }
}

resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.complicate_vpc.id
  tags = {
    Name = "public_rtb"
  }
}

resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.complicate_vpc.id
  tags = {
    Name = "private_rtb"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.complicate_vpc.id
}

resource "aws_eip" "nat_eip" {
  vpc = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "Nat-Gateway"
  }
}

resource "aws_route" "public_route" {
  route_table_id = aws_route_table.public_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route" "private_route" {
  route_table_id = aws_route_table.private_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.natgw.id
}

resource "aws_route_table_association" "public_route_asso" {
  route_table_id = aws_route_table.public_rtb.id
  subnet_id = aws_subnet.public_subnet.id
}

resource "aws_route_table_association" "private_route_asso" {
  route_table_id = aws_route_table.private_rtb.id
  subnet_id = aws_subnet.private_subnet.id
}

resource "aws_instance" "bastion" {
  ami = "ami-0f3a440bbcff3d043"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public_subnet.id
  tags = {
    Name = "bastion-instance"
  }
}

resource "aws_instance" "private_instance" {
  ami = "ami-0f3a440bbcff3d043"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private_subnet.id
  tags = {
    Name = "bastion-instance"
  }
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.complicate_vpc.id
  name = "bastion_sg"
  description = "security group for bastion instance"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    description = "ssh"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.complicate_vpc.id
  name = "private_sg"
  description = "security group for private instance"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    description = "ssh"
    security_groups = [aws_security_group.bastion_sg.id]
  }
}