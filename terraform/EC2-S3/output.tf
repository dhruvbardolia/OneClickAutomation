output "public_ip" {
  value = aws_eip.dev.public_ip
}

output "s3_url" {
  value = aws_s3_bucket_website_configuration.s3_bucket.website_endpoint
}

output "s3_name" {
  value = aws_s3_bucket_website_configuration.s3_bucket.bucket
}