provider "aws" {
     access_key = var.access_key
     secret_key = var.secret_key
     region     = var.region
}
resource "aws_security_group" "allow_tls" {
  description = "Allow TLS inbound traffic"
  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}  
resource "aws_instance" "web" {
  ami                    = var.image_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_tls.id}"]
  
  tags = {
    Name = "Myinstance"
  }
}
