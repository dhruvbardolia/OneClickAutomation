# Timestamp 
locals {
  timestamp           = timestamp()
  timestamp_sanitized = replace("${local.timestamp}", "/[-| |T|Z|:]/", "")
}

# Creating RDS Snapshot and Creating RDS instance from it

resource "aws_db_snapshot" "prod" {
  db_instance_identifier = "trainingamigo-prod"
  db_snapshot_identifier = "${var.name}-snapshot-${local.timestamp_sanitized}"
}

resource "aws_db_instance" "my_db" {
  identifier             = "${var.name}-rds-db"
  instance_class         = "db.t3.micro"
  snapshot_identifier    = aws_db_snapshot.prod.db_snapshot_identifier #"rds:snapshot-001"
  skip_final_snapshot    = true
  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name
  depends_on             = [aws_db_snapshot.prod]
}
