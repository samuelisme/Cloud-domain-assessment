terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  backend "s3" {
        bucket = "samuel99bucket" //S3 bucket to store Terraform state file
        key    = "state.tfstate"
        region  = "eu-west-2"
    }
}

provider "aws" {
  profile = "default"
  region  = "eu-west-2"
}

# Create a VPC
resource "aws_vpc" "app_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "app-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "vpc_igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone = "eu-west-2a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public_rt_asso" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_s3_bucket" "web_bucket" {
  bucket = "samuel-99-web-bucket"
 // acl    = "public-read"
  tags = {
    Name        = "web_instance"
  }
}


data "aws_s3_bucket" "selected-bucket" {
  bucket = aws_s3_bucket.web_bucket.bucket
}

resource "aws_s3_bucket_acl" "bucket-acl" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  acl    = "public-read"
}
/*
resource "aws_s3_bucket_versioning" "bucket-versioning" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
*/
resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  policy = data.aws_iam_policy_document.iam-policy-1.json
}
data "aws_iam_policy_document" "iam-policy-1" {
  statement {
    sid    = "AllowPublicRead"
    effect = "Allow"
resources = [
      aws_s3_bucket.web_bucket.arn,
      "${aws_s3_bucket.web_bucket.arn}/*",
    ]
actions = ["S3:GetObject"]
principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = data.aws_s3_bucket.selected-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
      //Amazon S3-managed keys (SSE-S3)
    }
  }
}

resource "aws_instance" "web" {
  //ami             = "ami-084e8c05825742534"  Amazon AMI
  ami             = "ami-02061e00ad9d457bd" // Own by me
  instance_type   = var.instance_type
  key_name        = var.instance_key
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.sg.id]

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing apache2"
  sudo yum update -y
  sudo amazon-linux-extras install php8.0 mariadb10.5 -y
  sudo yum install -y httpd
  sudo systemctl start httpd
  sudo systemctl enable httpd
  sudo usermod -a -G apache ec2-user
  sudo yum install -y mod_ssl
  cd /etc/pki/tls/certs
  sudo ./make-dummy-cert localhost.crt
  echo "*** Completed Installing apache2"
  EOF

  tags = {
    Name = "web_instance"
  }

  volume_tags = {
    Name = "web_instance"
  } 

  provisioner "file" {
    source      = "./README.md"
    destination = "/home/ec2-user/README.md"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/Users/samuelchan/dev/dev.pem")
      host        = self.public_ip
    }
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = "eipalloc-08794bcd0b410aae0"
}

resource "aws_ebs_encryption_by_default" "ebs_encrypt" {
  enabled = true //AWS-managed default CMK
}