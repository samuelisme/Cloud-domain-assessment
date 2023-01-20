variable "region" {
    default = "us-west-2"
}
variable "instance_type" {}
variable "creds" {}
variable "instance_key" {}
variable "vpc_cidr" {
    type = string
}
variable "public_subnet_cidr" {}