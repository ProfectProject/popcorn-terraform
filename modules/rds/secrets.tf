# Random password for RDS (선택적)
resource "random_password" "db_password" {
  count = var.create_random_password ? 1 : 0

  length  = 16
  special = true
}

# Store password in Secrets Manager (선택적)
resource "aws_secretsmanager_secret" "db_password" {
  count = var.create_secrets_manager ? 1 : 0

  name                    = "${var.identifier}-db-password"
  description             = "RDS PostgreSQL password for ${var.identifier}"
  recovery_window_in_days = var.secrets_recovery_window

  tags = merge(var.tags, {
    Name = "${var.identifier}-db-password"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count = var.create_secrets_manager ? 1 : 0

  secret_id = aws_secretsmanager_secret.db_password[0].id
  secret_string = jsonencode({
    username = var.master_username
    password = var.create_random_password ? random_password.db_password[0].result : var.master_password
    engine   = var.engine
    host     = aws_db_instance.main.address
    port     = var.database_port
    dbname   = var.database_name
  })
}
