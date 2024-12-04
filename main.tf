
provider "aws" {
  region = "us-east-1"  
}

variable "cidr" {
  default = "10.0.0.0/16"
}

resource "aws_key_pair" "example" {
  key_name   = "terraform-demo-node"  
  public_key = file("~/.ssh/id_rsa.pub")  
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}
resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-sg"
  }
}

resource "aws_instance" "server" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  key_name      = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id


  connection {
    type        = "ssh"
    user        = "ubuntu"  # Replace with the appropriate username for your EC2 instance
    private_key = file("~/.ssh/id_rsa")  
    host        = self.public_ip
  }

  
   provisioner "file" {
    source      = "index.js"  # Replace with the path to your local file
    destination = "/home/ubuntu/index.js"  # Replace with the path on the remote instance
  }
   provisioner "file" {
    source      = "package.json"  # Replace with the path to your local file
    destination = "/home/ubuntu/package.json"  # Replace with the path on the remote instance
  }
  provisioner "file" {
    source      = "Dockerfile"  # Replace with the path to your local file
    destination = "/home/ubuntu/Dockerfile"  # Replace with the path on the remote instance
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
"sudo apt-get  install -y docker",
"sudo apt-get  install -y docker.io",
"systemctl start docker",
"systemctl enable docker",  
"cd /home/ubuntu",
      "sudo docker build . -t akshaynodejs/1q",
      "sudo docker run -d --restart unless-stopped -p 3000:3000 akshaynodejs/1q"
    ]

  }

    
}

