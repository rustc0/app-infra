
provider "aws" {
	region = var.aws_region
	profile = "deez-ec2"
}

data "aws_ami" "Debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
	name   = "name"
	values = ["debian-13-amd64-*"]
  }

  filter {
	name = "virtualization-type"
	values = ["hvm"]
  }
}

resource "aws_security_group" "vm" {
	name = "${var.project_name}-sg"
	description = "Allow SSH, HTTP and HTTPS inbound traffic"

	ingress {
		description = "SSH"
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = [var.ssh_allowed_cidr]
	}

	ingress {
		description = "HTTP"
		from_port   = 80
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		description = "HTTPS"
		from_port   = 443
		to_port     = 443
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		description = "All outbound traffic"
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "${var.project_name}-sg"
	}
}

resource "aws_instance" "vm" {
	ami           = data.aws_ami.Debian.id
	instance_type = var.instance_type
	key_name      = var.key_pair_name
	vpc_security_group_ids = [aws_security_group.vm.id]

	root_block_device {
		volume_size = var.root_volume_size
		volume_type = "gp3"
	}

	tags = {
		Name = "${var.project_name}-vm"
	}
}
