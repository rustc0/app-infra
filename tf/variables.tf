variable "project_name" {
  description = "The name of the project"
  type        = string
  default = "Deez-ec2"
}

variable "aws_region" {
  description = "The region where the project will be deployed"
  type        = string
  default = "us-east-1"
}

variable "instance_type" {
  description = "The type of the EC2 instance"
  type        = string
  default = "t3.micro"
}

variable "root_volume_size" {
  description = "The size of the root volume"
  type        = number
  default = 20
}

variable "key_pair_name" {
  description = "Name of the existing EC2 key pair used for SSH"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH, e.g. \"1.2.3.4/32\""
  type        = string
}