variable "name" {
  description = "Human friendly name that prefixes created resources"
  type        = string
  default     = "dev-environment-launch-template"
}

variable "iam_profile" {
  description = "IAM instance profile associated with the EC2 instances"
  type        = string
}

variable "image_id" {
  description = "AMI ID used by the launch template"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name for EC2 access"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs attached to the launch template"
  type        = list(string)
}

variable "subnets" {
  description = "Subnet IDs used by the auto scaling group"
  type        = list(string)
}

variable "route53_zone_id" {
  description = "Hosted zone ID for backend DNS records"
  type        = string
}

variable "root_domain" {
  description = "Primary domain associated with the hosted zone"
  type        = string
}

variable "frontend_bucket_suffix" {
  description = "Suffix appended to generated S3 bucket names (e.g. fe.example.com)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}
