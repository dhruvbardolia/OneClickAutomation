output "rds_name" {
  value = aws_db_instance.my_db.identifier
}

output "rds_endpoint" {
  value = aws_db_instance.my_db.endpoint
}