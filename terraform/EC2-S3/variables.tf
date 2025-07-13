variable "name" {
  type    = string
  default = "dev-environment-launch-template"
}

variable "iam_profile" {
  type = string
}

variable "image_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "subnets" {
  type = list(string)
}