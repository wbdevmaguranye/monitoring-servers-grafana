variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  default = "ami-0866a3c8686eaeeba" # Replace with a valid AMI ID
}

variable "public_key_path" {
  default = "monitoring.pub" # Reference the file by its relative path
}

variable "monitoring_key" {
  default = "generated-key"
}
