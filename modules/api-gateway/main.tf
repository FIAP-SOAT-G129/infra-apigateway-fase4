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

#############
resource "aws_api_gateway_resource" "paths" {
  for_each = local.unique_path_segments

  rest_api_id = aws_api_gateway_rest_api.this.id
  path_part   = each.value.part

  parent_id = each.value.index == 0 ? aws_api_gateway_rest_api.this.root_resource_id : aws_api_gateway_resource.paths[each.value.parent].id
}

resource "aws_api_gateway_method" "methods" {
  for_each = local.api_routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.paths[each.value.path].id
  http_method = each.value.method

  authorization = local.route_auth[each.key] != null ? "CUSTOM" : "NONE"
  authorizer_id = local.route_auth[each.key] != null ? aws_api_gateway_authorizer.lambda_auth.id : null

  request_parameters = {
    for param in each.value.path_params :
    "method.request.path.${param}" => true
  }
}

resource "aws_api_gateway_integration" "integrations" {
  for_each = local.api_routes

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.paths[each.value.path].id
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  integration_http_method = each.value.method
  type                    = "HTTP_PROXY"

  uri = "http://${var.alb_dns_name}${each.value.alb_path}"

  request_parameters = {
    for param in each.value.path_params :
    "integration.request.path.${param}" => "method.request.path.${param}"
  }
}
############

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeploy = sha1(jsonencode(local.api_routes))
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
