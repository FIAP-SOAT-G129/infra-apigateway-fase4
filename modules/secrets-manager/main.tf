resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.name}-jwt-secret"
  description             = "JWT secret for Lambda authorizer"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_secret_version" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    jwt_secret = var.jwt_secret
  })
}
