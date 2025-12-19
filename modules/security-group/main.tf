resource "aws_security_group" "lambda_sg" {
  name        = "${var.name}-lambda-sg"
  description = "Security group for Lambda to access internal ALB"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.name}-lambda-sg" }
  )
}
