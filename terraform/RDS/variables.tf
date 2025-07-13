variable "name" {
  type    = string
  default = "dev-environment-launch-template"
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "db_subnet_group_name" {
  type = string
}