locals {
  timestamp            = timestamp()
  timestamp_sanitized  = regexreplace(local.timestamp, "[^0-9]", "")
  frontend_bucket_name = "${var.name}-${local.timestamp_sanitized}-${var.frontend_bucket_suffix}"
}

resource "aws_eip" "dev" {
  domain = "vpc"

  tags = {
    environment = "${var.name}-dev"
  }
}

resource "aws_route53_record" "backend" {
  zone_id         = var.route53_zone_id
  name            = "${var.name}-api.${var.root_domain}"
  type            = "A"
  ttl             = 300
  records         = [aws_eip.dev.public_ip]
  allow_overwrite = true

  depends_on = [aws_eip.dev]
}

resource "aws_launch_template" "my_launch_template" {
  name                   = "${var.name}-lt"
  description            = "Launch template for ${var.name} environment"
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

  monitoring {
    enabled = true
  }

  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = var.vpc_security_group_ids

  user_data = base64encode(
    templatefile("${path.module}/user_data.tpl", {
      allocation_id   = aws_eip.dev.allocation_id
      aws_region      = var.aws_region
      public_ip       = aws_eip.dev.public_ip
      record_fqdn     = trimsuffix(aws_route53_record.backend.fqdn, ".")
      route53_zone_id = var.route53_zone_id
    })
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

  depends_on = [aws_route53_record.backend]
}

resource "aws_autoscaling_group" "my_autoscaling_group" {
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

resource "aws_s3_bucket" "s3_bucket" {
  bucket        = local.frontend_bucket_name
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

  depends_on = [
    aws_s3_bucket.s3_bucket,
    aws_s3_bucket_versioning.versioning_s3_bucket,
  ]
}

resource "aws_s3_bucket_public_access_block" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  depends_on = [
    aws_s3_bucket.s3_bucket,
    aws_s3_bucket_versioning.versioning_s3_bucket,
    aws_s3_bucket_website_configuration.s3_bucket,
  ]
}

resource "aws_s3_bucket_policy" "access" {
  bucket = aws_s3_bucket.s3_bucket.id

  policy = jsonencode({
    Id = "PublicReadPolicy"
    Statement = [
      {
        Action    = ["s3:GetObject"]
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.s3_bucket.arn}/*"
        Principal = "*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket.s3_bucket,
    aws_s3_bucket_versioning.versioning_s3_bucket,
    aws_s3_bucket_website_configuration.s3_bucket,
    aws_s3_bucket_public_access_block.s3_bucket,
  ]
}
