variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "my_ip" {
  description = "Your public IP in CIDR form, allowed to SSH into the bastion (e.g. 49.37.10.20/32)"
  type        = string
  sensitive   = true
}
variable "public_key" {
  description = "SSH public key contents (the line from demo-key.pub)"
  type        = string
}