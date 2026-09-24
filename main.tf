# Latest Amazon Linux 2023 AMI, looked up automatically for the chosen region
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------
# Step 1: VPC
# ---------------------------------------------------------------
resource "aws_vpc" "demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "demo-vpc" }
}

# ---------------------------------------------------------------
# Step 2: Subnets (2 public, 2 private, across 2 AZs)
# ---------------------------------------------------------------
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.demo.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-1a" }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.demo.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-1b" }
}

resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"

  tags = { Name = "private-subnet-1a" }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.region}b"

  tags = { Name = "private-subnet-1b" }
}

# ---------------------------------------------------------------
# Step 3: Internet Gateway (created and attached in one resource)
# ---------------------------------------------------------------
resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = { Name = "demo-igw" }
}

# ---------------------------------------------------------------
# Step 4: Public route table -> Internet Gateway
# ---------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------
# Step 5: Elastic IP + NAT Gateway (zonal, in public-subnet-1a)
# ---------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "demo-nat-eip" }
}

resource "aws_nat_gateway" "demo" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1a.id

  tags = { Name = "demo-nat" }

  # The NAT needs the IGW to reach the internet
  depends_on = [aws_internet_gateway.demo]
}

# ---------------------------------------------------------------
# Step 6: Private route table -> NAT Gateway
# ---------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.demo.id
  }

  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------
# Step 7: Security groups
# Note: Terraform removes AWS's default "allow all outbound" rule,
# so outbound is added back explicitly below.
# ---------------------------------------------------------------
resource "aws_security_group" "public_ec2" {
  name        = "public-ec2-sg"
  description = "Allow SSH from my IP and HTTP from anywhere"
  vpc_id      = aws_vpc.demo.id

  tags = { Name = "public-ec2-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "public_ssh" {
  security_group_id = aws_security_group.public_ec2.id
  description       = "SSH from my IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.my_ip
}

resource "aws_vpc_security_group_ingress_rule" "public_http" {
  security_group_id = aws_security_group.public_ec2.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "public_all_out" {
  security_group_id = aws_security_group.public_ec2.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "private_ec2" {
  name        = "private-ec2-sg"
  description = "Allow SSH and HTTP only from the bastion"
  vpc_id      = aws_vpc.demo.id

  tags = { Name = "private-ec2-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "private_ssh" {
  security_group_id            = aws_security_group.private_ec2.id
  description                  = "SSH from bastion SG"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.public_ec2.id
}

resource "aws_vpc_security_group_ingress_rule" "private_http" {
  security_group_id            = aws_security_group.private_ec2.id
  description                  = "HTTP from bastion SG"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.public_ec2.id
}

resource "aws_vpc_security_group_egress_rule" "private_all_out" {
  security_group_id = aws_security_group.private_ec2.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------
# Step 8: Key pair (uploads only the PUBLIC key)
# ---------------------------------------------------------------
resource "aws_key_pair" "demo" {
  key_name   = "demo-key"
  public_key = var.public_key
}

# ---------------------------------------------------------------
# Step 9: EC2 instances with the web page user data
# ---------------------------------------------------------------
resource "aws_instance" "public" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_1a.id
  vpc_security_group_ids      = [aws_security_group.public_ec2.id]
  key_name                    = aws_key_pair.demo.key_name
  associate_public_ip_address = true

  user_data                   = file("${path.module}/userdata.sh")
  user_data_replace_on_change = true

  tags = { Name = "public-ec2" }
}

resource "aws_instance" "private" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_1a.id
  vpc_security_group_ids      = [aws_security_group.private_ec2.id]
  key_name                    = aws_key_pair.demo.key_name
  associate_public_ip_address = false

  user_data                   = file("${path.module}/userdata.sh")
  user_data_replace_on_change = true

  tags = { Name = "private-ec2" }

  # Boot only after the NAT route exists, so "dnf install httpd" can reach the internet
  depends_on = [aws_route_table_association.private_1a]
}
