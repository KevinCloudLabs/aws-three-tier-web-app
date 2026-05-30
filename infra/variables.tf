variable "aws_region" {
  description = "AWS Region to deploy into"
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "Used to prefix all resource names"
  type        = string
  default     = "ecommerce"
}

variable "my_ip" {
  description = "My local IP address for SSH access"
  type        = string 
}

variable "key_pair_name" {
  description = "Used as a key to allow SSH"
  type        = string
}

variable "db_password" {
  description = "Password for database"
  type        = string
  sensitive   = true 
}

variable "subscriber_email" {
  description = "Email used for SNS subscription"
  type        = string
}

variable "instance_connect_cidr" {
  description = "EC2 Instance Connect IP range for us-west-1"
  type        = string
  default     = "13.52.6.112/29"
}