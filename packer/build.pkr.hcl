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
  type = string
}

variable "APP_KEY" {
  type = string
}

variable "APP_URL" {
  type = string
}

variable "DB_HOST" {
  type = string
}

variable "DB_NAME" {
  type = string
}

variable "DB_USERNAME" {
  type = string
}

variable "DB_PASSWORD" {
  type = string
}

variable "SPARKPOST_SECRET" {
  type = string
}

variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}

variable "BUGSNAG_API_KEY" {
  type = string
}

variable "FCM_SERVER_KEY" {
  type = string
}

variable "STRIPE_KEY" {
  type = string
}

variable "STRIPE_SECRET" {
  type = string
}


source "amazon-ebs" "test" {
  #which ami to use as the base
  #where to save the ami
  ami_name   = "${var.AMI_NAME}"
  source_ami = "ami-0da7bb0769981faac" #ubuntu
  # source_ami      = "ami-03dc967a2cbd688e5" #base ami of ubuntu 20.04 having all tools and software dependencies
  instance_type = "t3.medium"
  region        = "us-east-1"
  ssh_username  = "ubuntu"
}

build {
  #what to install
  #configure
  #files to copy
  sources = [
    "source.amazon-ebs.test"
  ]
  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
    custom_data = {
      my_custom_data = "example"
    }
  }

  provisioner "shell" {
    inline = [
      "echo 'Script is running...'",
      "sleep 30", #packer recomends it, because it may take time for EC2 to be fully setup and ready",
      "sudo echo \"#!/bin/sh\" >> /home/ubuntu/rc.local",
      "sudo echo \"export APP_KEY='${var.APP_KEY}'\" >> /home/ubuntu/rc.local",
      "sudo echo \"export APP_URL=${var.APP_URL}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export DB_HOST=${var.DB_HOST}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export DB_NAME=${var.DB_NAME}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export DB_USERNAME=${var.DB_USERNAME}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export DB_PASSWORD='${var.DB_PASSWORD}'\" >> /home/ubuntu/rc.local",
      "sudo echo \"export SPARKPOST_SECRET=${var.SPARKPOST_SECRET}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export AWS_ACCESS_KEY_ID=${var.AWS_ACCESS_KEY_ID}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export AWS_SECRET_ACCESS_KEY=${var.AWS_SECRET_ACCESS_KEY}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export BUGSNAG_API_KEY=${var.BUGSNAG_API_KEY}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export FCM_SERVER_KEY=${var.FCM_SERVER_KEY}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export STRIPE_KEY=${var.STRIPE_KEY}\" >> /home/ubuntu/rc.local",
      "sudo echo \"export STRIPE_SECRET=${var.STRIPE_SECRET}\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo git config --global --add safe.directory /home/ubuntu/laravel\" >> /home/ubuntu/rc.local",
      "sudo echo \"cd /home/ubuntu/laravel\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo git pull \" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo git checkout ${var.BE_BRANCH_NAME}\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo git pull \" >> /home/ubuntu/rc.local",
      "sudo echo \"envsubst < /home/ubuntu/laravel/app-config.txt | cat - > .env.test\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo cat .env.test > .env\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo rm -rf composer.lock\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo composer install\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo php artisan key:generate\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo chmod -R 777 storage\" >> /home/ubuntu/rc.local",
      "sudo echo \"sudo php artisan serve\" >> /home/ubuntu/rc.local",
      "sudo echo \"Backend is configured!!!\"",
      "sudo chmod 777 /home/ubuntu/rc.local",
      "sudo echo \"Script is completed.\"",
      "sudo cp /home/ubuntu/rc.local /etc/rc.local",
      #   "sleep30",
      #   "cd /home/ubuntu/laravel",
      #   "sudo -u ubuntu git pull",
      #   "sudo -u ubuntu git checkout ${var.barnch_name}",
      #   "sudo -u ubuntu git pull",
      #   "cd /home/ubuntu",
      #   "touch /home/ubuntu/rc.local",
      #   "sudo echo \"cd /home/ubuntu/laravel\" >> /home/ubuntu/rc.local",
      #   "sudo echo \"composer install\" >> /home/ubuntu/rc.local",
      #   "sudo -u ubuntu git ",

    ]
  }
}