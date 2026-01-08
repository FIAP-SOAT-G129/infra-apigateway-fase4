# API Gateway
resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.name}-api"
  description = "FastFood REST API"
}

# Lambda Authorizer (Custom)
resource "aws_api_gateway_authorizer" "lambda_auth" {
  name                             = "fastfood-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  authorizer_uri                   = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_function_auth_arn}/invocations"
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 300
}

resource "aws_lambda_permission" "auth_permission" {
  statement_id  = "AllowAPIGatewayInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_auth_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# Rota pública: POST /login (Lambda)
resource "aws_api_gateway_resource" "login" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "login"
}

resource "aws_api_gateway_method" "login_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "login_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.login.id
  http_method             = aws_api_gateway_method.login_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_function_login_arn}/invocations"
}

resource "aws_lambda_permission" "login_permission" {
  statement_id  = "AllowAPIGatewayInvokeLogin"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_login_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# Level 0 Resources
resource "aws_api_gateway_resource" "level_0" {
  for_each = local.path_level_0

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.part
}

# Level 1 Resources
resource "aws_api_gateway_resource" "level_1" {
  for_each = local.path_level_1

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_0[each.value.parent].id
  path_part   = each.value.part
}

# Level 2 Resources
resource "aws_api_gateway_resource" "level_2" {
  for_each = local.path_level_2

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_1[each.value.parent].id
  path_part   = each.value.part
}

# Level 3 Resources
resource "aws_api_gateway_resource" "level_3" {
  for_each = local.path_level_3

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_2[each.value.parent].id
  path_part   = each.value.part
}

# Level 4 Resources
resource "aws_api_gateway_resource" "level_4" {
  for_each = local.path_level_4

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_3[each.value.parent].id
  path_part   = each.value.part
}

# API Gateway Methods
resource "aws_api_gateway_method" "methods" {
  for_each = var.api_routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = local.api_gateway_resources[each.value.path].id
  http_method = each.value.method

  authorization = length(local.route_auth[each.key]) > 0 ? "CUSTOM" : "NONE"
  authorizer_id = length(local.route_auth[each.key]) > 0 ? aws_api_gateway_authorizer.lambda_auth.id : null

  request_parameters = {
    for param in each.value.path_params :
    "method.request.path.${param}" => true
  }
}

# API Gateway Integrations (to ALB)
resource "aws_api_gateway_integration" "integrations" {
  for_each = var.api_routes

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = local.api_gateway_resources[each.value.path].id
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  integration_http_method = each.value.method
  type                    = "HTTP_PROXY"

  connection_type    = "VPC_LINK"
  connection_id      = var.vpc_link_id
  integration_target = var.alb_arn

  uri = "http://${var.alb_dns_name}${each.value.alb_path}"

  request_parameters = {
    for param in each.value.path_params :
    "integration.request.path.${param}" => "method.request.path.${param}"
  }
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeploy = sha1(jsonencode(var.api_routes))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.integrations,
    aws_api_gateway_integration.login_integration
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "dev"
}
