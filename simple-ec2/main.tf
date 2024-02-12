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

## AWS Provider
provider "aws" {
    access_key = local.envs["AWS_ACCESS_KEY_ID"]
    secret_key = local.envs["AWS_SECRET_ACCESS_KEY"]
    region = local.envs["AWS_REGION"]
}

##Setting up VPC
resource "aws_vpc" "ex-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "terraform-example"
    }
}

##Setting up Public Subnet
resource "aws_subnet" "ex-subnet" {
    vpc_id     = aws_vpc.ex-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-northeast-2a"
    tags       = {
        Name = "terraform-example"
    }
}

##Setting up Internet Gateway
resource "aws_internet_gateway" "ex-gateway" {
    vpc_id = aws_vpc.ex-vpc.id
    tags = {
        Name = "terraform-example"
    }
}

##Route Table for Internet Gateway
resource "aws_route_table" "ex-route-table" {
    vpc_id = aws_vpc.ex-vpc.id
    tags = {
        Name = "terraform-example"
    }
}

##Route Rule
resource "aws_route" "ex-route" {
    route_table_id         = aws_route_table.ex-route-table.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.ex-gateway.id
}


##Associating Route Table with Subnet
resource "aws_route_table_association" "ex-route-table-association" {
    subnet_id      = aws_subnet.ex-subnet.id
    route_table_id = aws_route_table.ex-route-table.id
}

##Ec2 Instance
resource "aws_instance" "ex-ec2" {
    ami = "ami-0f3a440bbcff3d043"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.ex-subnet.id
    tags = {
        Name = "terraform-example"
    }
}
