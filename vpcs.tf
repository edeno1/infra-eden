# Create VPC
resource "aws_vpc" "front_vpc" {
  cidr_block = "10.100.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id     = aws_vpc.front_vpc.id
  cidr_block = "10.100.64.0/20"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/cluster/test-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"  # Add this for ELB
    "kubernetes.io/role/internal-elb" = "1"  # Add this if needed for internal ELBs
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id     = aws_vpc.front_vpc.id
  cidr_block = "10.100.80.0/20"
  availability_zone = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/cluster/test-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
