output "lambda_sg_id" {
  description = "The ID of the security group associated with the Lambda"
  value       = aws_security_group.lambda_sg.id
}
