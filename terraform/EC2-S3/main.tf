locals {
  timestamp           = timestamp()
  timestamp_sanitized = replace("${local.timestamp}", "/[-| |T|Z|:]/", "")
}

resource "aws_eip" "dev" {
  domain = "vpc"
  tags = {
    environment = "${var.name}-dev"
  }
}

resource "aws_route53_record" "backend" {
  zone_id = "Z3CKWQV4EMIHXT"
  name    = "${var.name}-api"
  type    = "A"
  ttl     = 300
  records = ["1.2.3.4"]
}

resource "aws_launch_template" "my_launch_template" {
  name                   = "${var.name}-lt"
  description            = "Launch template for woliba testing environment for ${var.name}"
  update_default_version = true
  ebs_optimized          = false
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 20
      volume_type           = "gp3"
    }
  }

  iam_instance_profile {
    name = var.iam_profile
  }

  image_id = var.image_id

  instance_market_options {
    market_type = "spot"
  }

  # network_interfaces {
  #   security_groups             = var.vpc_security_group_ids
  #   associate_public_ip_address = true
  # }

  monitoring {
    enabled = true
  }

  instance_type = var.instance_type

  key_name = var.key_name

  vpc_security_group_ids = var.vpc_security_group_ids #["sg-12345678"]

  user_data = base64encode(
    <<-EOF
    #cloud-boothook
    #!/bin/bash
    sudo aws ec2 disassociate-address --region us-east-1 --public-ip ${aws_eip.dev.public_ip} >> /home/ubuntu/userdata.log
    sudo aws ec2 associate-address --region us-east-1 --instance-id "$(cat /sys/devices/virtual/dmi/id/board_asset_tag)" --allocation-id ${aws_eip.dev.allocation_id} 
    PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
    cat > /home/ubuntu/user.sh <<EOL
    {
        "Comment": "Update record to reflect new IP address for a system ",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "${aws_route53_record.backend.name}.trainingamigo.com",
                    "Type": "A",
                    "TTL": 60,
                    "ResourceRecords": [
                        {
                            "Value": "${aws_eip.dev.public_ip}"
                        }
                    ]
                }
            }
        ]
    }
    EOL
    aws route53 change-resource-record-sets --hosted-zone-id  Z3CKWQV4EMIHXT --change-batch file:///home/ubuntu/user.sh
    EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.name}-instance"
      environment = "${var.name}-dev"
    }
  }
  tag_specifications {
    resource_type = "volume"

    tags = {
      environment = "${var.name}-dev"
    }
  }
  tag_specifications {
    resource_type = "spot-instances-request"

    tags = {
      environment = "${var.name}-dev"
    }
  }
  depends_on = [aws_route53_record.backend, aws_eip.dev]
}

resource "aws_autoscaling_group" "my_autoscaling_group" {
  # availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  name                = "${var.name}-asg"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  health_check_type   = "EC2"
  vpc_zone_identifier = var.subnets
  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = aws_launch_template.my_launch_template.latest_version
  }
  tag {
    key                 = "environment"
    value               = "${var.name}-dev"
    propagate_at_launch = false
  }
  depends_on = [aws_launch_template.my_launch_template]
}

# Creating S3 Bucket with versioning and static website hosting enabled

resource "aws_s3_bucket" "s3_bucket" {
  bucket        = "${var.name}-${local.timestamp_sanitized}-fe.trainingamigo.com"
  force_destroy = true
  tags = {
    environment = "${var.name}-dev"
  }
}


resource "aws_s3_bucket_versioning" "versioning_s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
  depends_on = [aws_s3_bucket.s3_bucket]
}


resource "aws_s3_bucket_website_configuration" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
  depends_on = [aws_s3_bucket.s3_bucket, aws_s3_bucket_versioning.versioning_s3_bucket]
}

resource "aws_s3_bucket_public_access_block" "s3_bucket" {
  bucket     = aws_s3_bucket.s3_bucket.id
  depends_on = [aws_s3_bucket.s3_bucket, aws_s3_bucket_versioning.versioning_s3_bucket, aws_s3_bucket_website_configuration.s3_bucket]
}


resource "aws_s3_bucket_policy" "access" {
  bucket     = aws_s3_bucket.s3_bucket.id
  policy     = <<POLICY
{
  "Id": "Policy",
  "Statement": [
    {
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}/*",
      "Principal": {
        "AWS": [
          "*"
        ]
      }
    }
  ]
}
POLICY
  depends_on = [aws_s3_bucket.s3_bucket, aws_s3_bucket_versioning.versioning_s3_bucket, aws_s3_bucket_website_configuration.s3_bucket, aws_s3_bucket_public_access_block.s3_bucket]
}


# resource "aws_route53_record" "frontend" {
#   zone_id = "Z3CKWQV4EMIHXT"
#   name    = "${var.name}-${local.timestamp_sanitized}-fe"
#   type    = "A"
#   alias {
#     name                   = aws_s3_bucket_website_configuration.s3_bucket.website_endpoint
#     zone_id                = aws_s3_bucket.s3_bucket.hosted_zone_id
#     evaluate_target_health = true
#   }
# }


# aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=instance-id,Values=i-0b64c5fa087ac6124" --query 'Reservations[*].Instances[*].[PrivateIpAddress]' --output text
# sudo aws ec2 disassociate-address --region us-east-1 --public-ip ${aws_eip.dev.public_ip} >> /home/ubuntu/userdata.log
# sudo aws ec2 associate-address --region us-east-1 --instance-id "$(cat /sys/devices/virtual/dmi/id/board_asset_tag)" --allocation-id ${aws_eip.dev.allocation_id} >> /home/ubuntu/userdata.log
