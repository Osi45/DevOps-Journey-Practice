variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "The name of the SSH key pair"
  type        = string
  default     = "project3-key"
}

variable "ami_id" {
  description = "AMI ID to launch EC2 instances"
  type        = string
}

variable "project_name" {
  description = "Project name tag"
  type        = string
  default     = "DevOps-Project3"
}
