output "secret_name" {
  description = "Name of the JWT secret in Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.name
}
