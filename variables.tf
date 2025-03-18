variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "ami_id" {
  default = "ami-04aa00acb1165b32a"  
}