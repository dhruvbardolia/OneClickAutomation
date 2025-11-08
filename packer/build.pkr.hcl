packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "AMI_NAME" {
  default     = "test-ami"
  type        = string
  description = "Default AMI name"
}

variable "BE_BRANCH_NAME" {
  description = "Backend repository branch to deploy"
  type        = string
}

variable "APP_KEY" {
  description = "Laravel application key"
  type        = string
}

variable "APP_URL" {
  description = "Base application URL"
  type        = string
}

variable "DB_HOST" {
  description = "Database endpoint hostname"
  type        = string
}

variable "DB_NAME" {
  description = "Database name"
  type        = string
}

variable "DB_USERNAME" {
  description = "Database username"
  type        = string
}

variable "DB_PASSWORD" {
  description = "Database password"
  type        = string
}

variable "SPARKPOST_SECRET" {
  description = "SparkPost API secret"
  type        = string
}

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key ID for the application"
  type        = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS secret access key for the application"
  type        = string
}

variable "BUGSNAG_API_KEY" {
  description = "Bugsnag API key"
  type        = string
}

variable "FCM_SERVER_KEY" {
  description = "Firebase Cloud Messaging server key"
  type        = string
}

variable "STRIPE_KEY" {
  description = "Stripe publishable key"
  type        = string
}

variable "STRIPE_SECRET" {
  description = "Stripe secret key"
  type        = string
}

locals {
  base_ami      = "ami-0da7bb0769981faac"
  instance_type = "t3.medium"
  manifest_path = "manifest.json"
  rc_local_path = "/home/ubuntu/rc.local"
  region        = "us-east-1"
  ssh_username  = "ubuntu"
}


source "amazon-ebs" "test" {
  // Base AMI and target image metadata
  ami_name      = var.AMI_NAME
  source_ami    = local.base_ami
  instance_type = local.instance_type
  region        = local.region
  ssh_username  = local.ssh_username
}

build {
  sources = ["source.amazon-ebs.test"]

  provisioner "shell" {
    inline = [
      "echo '[Provisioner] Waiting for instance readiness...'",
      "sleep 30",
      <<-RCLOCAL,
cat <<'RC_LOCAL' | sudo tee ${local.rc_local_path} > /dev/null
#!/bin/sh
export APP_KEY='${var.APP_KEY}'
export APP_URL=${var.APP_URL}
export DB_HOST=${var.DB_HOST}
export DB_NAME=${var.DB_NAME}
export DB_USERNAME=${var.DB_USERNAME}
export DB_PASSWORD='${var.DB_PASSWORD}'
export SPARKPOST_SECRET=${var.SPARKPOST_SECRET}
export AWS_ACCESS_KEY_ID=${var.AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${var.AWS_SECRET_ACCESS_KEY}
export BUGSNAG_API_KEY=${var.BUGSNAG_API_KEY}
export FCM_SERVER_KEY=${var.FCM_SERVER_KEY}
export STRIPE_KEY=${var.STRIPE_KEY}
export STRIPE_SECRET=${var.STRIPE_SECRET}
sudo git config --global --add safe.directory /home/ubuntu/laravel
cd /home/ubuntu/laravel
sudo git pull
sudo git checkout ${var.BE_BRANCH_NAME}
sudo git pull
envsubst < /home/ubuntu/laravel/app-config.txt | cat - > .env.test
sudo cat .env.test > .env
sudo rm -rf composer.lock
sudo composer install
sudo php artisan key:generate
sudo chmod -R 777 storage
sudo php artisan serve
echo "Backend is configured!!!"
RC_LOCAL
      RCLOCAL,
      "sudo chmod 755 ${local.rc_local_path}",
      "sudo cp ${local.rc_local_path} /etc/rc.local",
      "sudo chmod 755 /etc/rc.local",
      "echo '[Provisioner] rc.local installed.'"
    ]
  }

  post-processor "manifest" {
    output     = local.manifest_path
    strip_path = true
    custom_data = {
      my_custom_data = "example"
    }
  }
}
