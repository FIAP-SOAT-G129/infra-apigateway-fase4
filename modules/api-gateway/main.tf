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

# Rota privada: GET /v1/orders/customers/{customerId} (EKS via NLB)
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "orders_customer" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "orders"
}

resource "aws_api_gateway_resource" "orders_customer_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_customer.id
  path_part   = "customers"
}

resource "aws_api_gateway_resource" "orders_customer_param" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_customer_id.id
  path_part   = "{customerId}"
}

resource "aws_api_gateway_method" "orders_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_customer_param.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.customerId" = true
  }
}

resource "aws_api_gateway_integration" "orders_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_customer_param.id
  http_method             = aws_api_gateway_method.orders_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.lb_port}/v1/orders/customers/{customerId}"

  request_parameters = {
    "integration.request.path.customerId" = "method.request.path.customerId"
  }
}

# Proxy público genérico: ANY /{proxy+}
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.lb_port}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# MS PAGAMENTOS (porta 8082)

# /v1/payments
resource "aws_api_gateway_resource" "payments" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders.id  # já existe /v1
  path_part   = "payments"
}

# POST /v1/payments
resource "aws_api_gateway_method" "payments_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.payments.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "payments_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.payments.id
  http_method             = aws_api_gateway_method.payments_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.payment_port}/v1/payments/"
}

# GET /v1/payments/{id}
resource "aws_api_gateway_resource" "payments_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payments.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "payments_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.payments_id.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "payments_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.payments_id.id
  http_method             = aws_api_gateway_method.payments_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.payment_port}/v1/payments/{id}"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# /v1/payments/orders
resource "aws_api_gateway_resource" "payments_orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payments.id
  path_part   = "orders"
}

# GET /v1/payments/orders/{id}
resource "aws_api_gateway_resource" "payments_orders_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.payments_orders.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "payments_orders_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.payments_orders_id.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "payments_orders_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.payments_orders_id.id
  http_method             = aws_api_gateway_method.payments_orders_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.payment_port}/v1/payments/orders/{id}"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# MS CATALOG (porta 8080)

# /v1/products
resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders.id  # já existe /v1
  path_part   = "products"
}

# GET /v1/products/{id}
resource "aws_api_gateway_resource" "products_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "products_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_id.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "products_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_id.id
  http_method             = aws_api_gateway_method.products_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/products/{id}"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# POST /v1/products
resource "aws_api_gateway_method" "products_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "products_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products.id
  http_method             = aws_api_gateway_method.products_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/products"
}

# PUT /v1/products/{id}
resource "aws_api_gateway_method" "products_put" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_id.id
  http_method   = "PUT"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "products_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_id.id
  http_method             = aws_api_gateway_method.products_put.http_method
  integration_http_method = "PUT"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/products/{id}"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# DELETE /v1/products/{id}
resource "aws_api_gateway_method" "products_delete" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_id.id
  http_method   = "DELETE"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "products_delete_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_id.id
  http_method             = aws_api_gateway_method.products_delete.http_method
  integration_http_method = "DELETE"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/products/{id}"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# PATCH /v1/products/reserve
resource "aws_api_gateway_resource" "products_reserve" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "reserve"
}

resource "aws_api_gateway_method" "products_reserve_patch" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_reserve.id
  http_method   = "PATCH"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "products_reserve_patch_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_reserve.id
  http_method             = aws_api_gateway_method.products_reserve_patch.http_method
  integration_http_method = "PATCH"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/products/reserve"
}

# PATCH /v1/products/confirm
resource "aws_api_gateway_resource" "products_confirm" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "confirm"
}

resource "aws_api_gateway_method" "products_confirm_patch" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_confirm.id
  http_method   = "PATCH"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "products_confirm_patch_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_confirm.id
  http_method             = aws_api_gateway_method.products_confirm_patch.http_method
  integration_http_method = "PATCH"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/products/confirm"
}

# PATCH /v1/products/release
resource "aws_api_gateway_resource" "products_release" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "release"
}

resource "aws_api_gateway_method" "products_release_patch" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.products_release.id
  http_method   = "PATCH"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "products_release_patch_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.products_release.id
  http_method             = aws_api_gateway_method.products_release_patch.http_method
  integration_http_method = "PATCH"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/products/release"
}

# /v1/customers
resource "aws_api_gateway_resource" "customers" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders.id  # já existe /v1
  path_part   = "customers"
}

# POST /v1/customers
resource "aws_api_gateway_method" "customers_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.customers.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "customers_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.customers.id
  http_method             = aws_api_gateway_method.customers_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/customers"
}

# GET /v1/customers/{cpf}
resource "aws_api_gateway_resource" "customers_cpf" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.customers.id
  path_part   = "{cpf}"
}

resource "aws_api_gateway_method" "customers_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.customers_cpf.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.cpf" = true
  }
}

resource "aws_api_gateway_integration" "customers_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.customers_cpf.id
  http_method             = aws_api_gateway_method.customers_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.catalog_port}/v1/customers/{cpf}"

  request_parameters = {
    "integration.request.path.cpf" = "method.request.path.cpf"
  }
}

# MS ORDER (porta 8081)

# POST /v1/orders 
resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_customer.id  # /v1/orders
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "orders_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_customer.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.order_port}/v1/orders"
}

# GET /v1/orders/active
resource "aws_api_gateway_resource" "orders_active" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_customer.id  # /v1/orders
  path_part   = "active"
}

resource "aws_api_gateway_method" "orders_active_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_active.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id
}

resource "aws_api_gateway_integration" "orders_active_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_active.id
  http_method             = aws_api_gateway_method.orders_active_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.order_port}/v1/orders/active"
}

# /v1/orders/{orderId}
resource "aws_api_gateway_resource" "orders_order_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_customer.id
  path_part   = "{orderId}"
}

# /v1/orders/{orderId}/combos
resource "aws_api_gateway_resource" "orders_combos" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_order_id.id
  path_part   = "combos"
}

# POST /v1/orders/{orderId}/combos
resource "aws_api_gateway_method" "orders_combos_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_combos.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.orderId" = true
  }
}

resource "aws_api_gateway_integration" "orders_combos_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_combos.id
  http_method             = aws_api_gateway_method.orders_combos_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.order_port}/v1/orders/{orderId}/combos"

  request_parameters = {
    "integration.request.path.orderId" = "method.request.path.orderId"
  }
}

# /v1/orders/{orderId}/combos/{comboId}
resource "aws_api_gateway_resource" "orders_combos_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_combos.id
  path_part   = "{comboId}"
}

# PUT /v1/orders/{orderId}/combos/{comboId}
resource "aws_api_gateway_method" "orders_combos_put" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_combos_id.id
  http_method   = "PUT"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.orderId" = true
    "method.request.path.comboId" = true
  }
}

resource "aws_api_gateway_integration" "orders_combos_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_combos_id.id
  http_method             = aws_api_gateway_method.orders_combos_put.http_method
  integration_http_method = "PUT"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.order_port}/v1/orders/{orderId}/combos/{comboId}"

  request_parameters = {
    "integration.request.path.orderId" = "method.request.path.orderId"
    "integration.request.path.comboId" = "method.request.path.comboId"
  }
}

# DELETE /v1/orders/{orderId}/combos/{comboId}
resource "aws_api_gateway_method" "orders_combos_delete" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_combos_id.id
  http_method   = "DELETE"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.orderId" = true
    "method.request.path.comboId" = true
  }
}

resource "aws_api_gateway_integration" "orders_combos_delete_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_combos_id.id
  http_method             = aws_api_gateway_method.orders_combos_delete.http_method
  integration_http_method = "DELETE"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.order_port}/v1/orders/{orderId}/combos/{comboId}"

  request_parameters = {
    "integration.request.path.orderId" = "method.request.path.orderId"
    "integration.request.path.comboId" = "method.request.path.comboId"
  }
}

# /v1/orders/{id}/payment-confirmed
resource "aws_api_gateway_resource" "orders_payment_confirmed" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders_order_id.id
  path_part   = "payment-confirmed"
}

# PATCH /v1/orders/{id}/payment-confirmed
resource "aws_api_gateway_method" "orders_payment_confirmed_patch" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders_payment_confirmed.id
  http_method   = "PATCH"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_auth.id

  request_parameters = {
    "method.request.path.orderId" = true
  }
}

resource "aws_api_gateway_integration" "orders_payment_confirmed_patch_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders_payment_confirmed.id
  http_method             = aws_api_gateway_method.orders_payment_confirmed_patch.http_method
  integration_http_method = "PATCH"
  type                    = "HTTP_PROXY"
  uri                     = "http://${data.aws_lb.internal_nlb.dns_name}:${var.order_port}/v1/orders/{orderId}/payment-confirmed"

  request_parameters = {
    "integration.request.path.orderId" = "method.request.path.orderId"
  }
}

# Deployment e Stage
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  depends_on = [
    aws_api_gateway_integration.login_integration,
    aws_api_gateway_integration.orders_get_integration,
    aws_api_gateway_integration.proxy_integration,
    
    # Payments
    aws_api_gateway_integration.payments_post_integration,
    aws_api_gateway_integration.payments_get_integration,
    aws_api_gateway_integration.payments_orders_get_integration,
    
    # Products
    aws_api_gateway_integration.products_get_integration,
    aws_api_gateway_integration.products_post_integration,
    aws_api_gateway_integration.products_put_integration,
    aws_api_gateway_integration.products_delete_integration,
    aws_api_gateway_integration.products_reserve_patch_integration,
    aws_api_gateway_integration.products_confirm_patch_integration,
    aws_api_gateway_integration.products_release_patch_integration,
    
    # Customers
    aws_api_gateway_integration.customers_post_integration,
    aws_api_gateway_integration.customers_get_integration,
    
    # Orders
    aws_api_gateway_integration.orders_post_integration,
    aws_api_gateway_integration.orders_active_get_integration,
    aws_api_gateway_integration.orders_combos_post_integration,
    aws_api_gateway_integration.orders_combos_put_integration,
    aws_api_gateway_integration.orders_combos_delete_integration,
    aws_api_gateway_integration.orders_payment_confirmed_patch_integration
  ]
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "dev"
}
