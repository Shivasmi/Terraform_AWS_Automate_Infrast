provider "aws" {
    region = "us-east-1"
    access_key = "AKIA4E2UW7PBPLHEOP7N"
    secret_key = "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"
}
resource "aws_instance" "my-server" {
  ami           = "ami-085925f297f89fce1"
  instance_type = "t2.micro"
  tags = {
    name = "ubuntu server"
  }
}
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Production"
  }
}

resource "aws_subnet" "subnet-1"{
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet"
  }

}


# Here we are creating a custom VPC 
resource "aws_vpc" "test-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Test"
  }
}

# create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "Test"
  }
}

#create custom route table 
resource "aws_route_table" "test-route-table" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Test"
  }
}

# create a subnet
resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.test-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags ={
    Name = "test-subnet"
  }
}

# This will associate sunnet with route table 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.test-route-table.id
}

# Here will create a security group to allow port 22, 80, 443 traffic

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  ingress {
    description      = "https from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
  ingress {
    description      = "http from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7 create network interface
resource "aws_network_interface" "web-test-nw" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8 create elastic ip 

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-test-nw.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
  
}

#9 create ubuntu server 

resource "aws_instance" "web-server-instance" {
  ami = "ami-0574da719dca65348"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"
  network_interface {
    device_index =0 
    network_interface_id = aws_network_interface.web-test-nw.id
  }
  user_data = <<-EOF

              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your first web test >/var/html/index.html'
              EOF

  tags = {
    Name = "test-web"
  }

}


