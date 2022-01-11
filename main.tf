provider "aws"{
    region = "us-east-1"
    access_key = var.aws_env.access
    secret_key = var.aws_env.secret
}

# 1. Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
      Name = var.environment
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}

# 3. Create Custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"  //0 means allow all from 0 ~ 255 for ipv4
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# 4. Create a Subnet
resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags={
        Name = "prod-subnet"
    }

}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "subnet-route-table" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

/* 6. Create Security Group to allow port 22, 80, 443
    22 - SSH into server
    80 - HTTP
    442 - HTTPS
*/
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] // specifying which ip can access, as sometimes your web application might only open for certain computer
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] // specifying which ip can access, as sometimes your web application might only open for certain computer
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] // specifying which ip can access, as sometimes your web application might only open for certain computer
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"  // -1 means allow all
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-network-interface" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8. Assign an elastic IP (public IP) to the network interface created in step 7 so that everyone on internet able to access it
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-network-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw] //Either we configure internet gateway terraform configuration first become setting up the EIP, otherwise, assign this "depends_on" property so that it understand the sequence
}

# 9. Create Ubuntu server and install/enable apache 2
resource "aws_instance" "web-server-instance" {
    ami = "ami-0e472ba40eb589f49"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a" //need to same as subnet zone (Refers in Step 4)
    key_name = "main-key"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-network-interface.id
    }

  //Write a dummy text into index.html on apache server
  #  user_data = <<-EOF
  #                #!/bin/bash
  #                sudo apt update -y
  #                sudo apt install apache2 -y
  #                sudo systemctl start apache2
  #                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
  #                EOF
        
    tags = {
        Name = "web-server"
    }
}