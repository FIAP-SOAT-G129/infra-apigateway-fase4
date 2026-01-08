locals {
  api_routes = {
    # Categories
    get_categories = {
      method      = "GET"
      path        = "v1/categories"
      alb_path    = "/v1/categories"
      auth_roles  = ["employee"]
      path_params = []
    }

    get_categories_by_id = {
      method      = "GET"
      path        = "v1/categories/{categoryId}"
      alb_path    = "/v1/categories/{categoryId}"
      auth_roles  = ["employee"]
      path_params = ["categoryId"]
    }

    create_category = {
      method      = "POST"
      path        = "v1/categories"
      alb_path    = "/v1/categories"
      auth_roles  = ["employee"]
      path_params = []
    }

    update_category = {
      method      = "PUT"
      path        = "v1/categories/{categoryId}"
      alb_path    = "/v1/categories/{categoryId}"
      auth_roles  = ["employee"]
      path_params = ["categoryId"]
    }

    delete_category = {
      method      = "DELETE"
      path        = "v1/categories/{categoryId}"
      alb_path    = "/v1/categories/{categoryId}"
      auth_roles  = ["employee"]
      path_params = ["categoryId"]
    }

    # Products
    get_products_by_category = {
      method      = "GET"
      path        = "v1/products/category/{categoryId}"
      alb_path    = "/v1/products/category/{categoryId}"
      auth_roles  = ["employee"]
      path_params = ["categoryId"]
    }

    get_product_by_id = {
      method      = "GET"
      path        = "v1/products/{productId}"
      alb_path    = "/v1/products/{productId}"
      auth_roles  = ["employee", "customer"]
      path_params = ["productId"]
    }

    create_product = {
      method      = "POST"
      path        = "v1/products"
      alb_path    = "/v1/products"
      auth_roles  = ["employee"]
      path_params = []
    }

    update_product = {
      method      = "PUT"
      path        = "v1/products/{productId}"
      alb_path    = "/v1/products/{productId}"
      auth_roles  = ["employee"]
      path_params = ["productId"]
    }

    delete_product = {
      method      = "DELETE"
      path        = "v1/products/{productId}"
      alb_path    = "/v1/products/{productId}"
      auth_roles  = ["employee"]
      path_params = ["productId"]
    }

    # Customers
    create_customer = {
      method      = "POST"
      path        = "v1/customers"
      alb_path    = "/v1/customers"
      auth_roles  = []
      path_params = []
    }

    # Employees
    create_employee = {
      method      = "POST"
      path        = "v1/employees"
      alb_path    = "/v1/employees"
      auth_roles  = []
      path_params = []
    }

    # Orders
    get_orders = {
      method      = "GET"
      path        = "v1/orders"
      alb_path    = "/v1/orders"
      auth_roles  = []
      path_params = []
    }

    get_active_orders = {
      method      = "GET"
      path        = "v1/orders/active"
      alb_path    = "/v1/orders/active"
      auth_roles  = []
      path_params = []
    }

    get_orders_by_id = {
      method      = "GET"
      path        = "v1/orders/{orderId}"
      alb_path    = "/v1/orders/{orderId}"
      auth_roles  = ["customer"]
      path_params = ["orderId"]
    }

    create_order = {
      method      = "POST"
      path        = "v1/orders"
      alb_path    = "/v1/orders"
      auth_roles  = ["customer"]
      path_params = []
    }

    add_combo_to_order = {
      method      = "POST"
      path        = "v1/orders/{orderId}/combos"
      alb_path    = "/v1/orders/{orderId}/combos"
      auth_roles  = ["customer"]
      path_params = ["orderId"]
    }

    update_combo_from_order = {
      method      = "PUT"
      path        = "v1/orders/{orderId}/combos/{comboId}"
      alb_path    = "/v1/orders/{orderId}/combos/{comboId}"
      auth_roles  = ["customer"]
      path_params = ["orderId", "comboId"]
    }

    delete_combo_from_order = {
      method      = "DELETE"
      path        = "v1/orders/{orderId}/combos/{comboId}"
      alb_path    = "/v1/orders/{orderId}/combos/{comboId}"
      auth_roles  = ["customer"]
      path_params = ["orderId", "comboId"]
    }

    # Payments
    get_payment_by_id = {
      method      = "GET"
      path        = "v1/payments/{paymentId}"
      alb_path    = "/v1/payments/{paymentId}"
      auth_roles  = ["customer"]
      path_params = ["paymentId"]
    }

    get_payment_by_order = {
      method      = "GET"
      path        = "v1/payments/orders/{orderId}"
      alb_path    = "/v1/payments/orders/{orderId}"
      auth_roles  = ["customer"]
      path_params = ["orderId"]
    }

    # Webhook for MercadoPago
    mercadopago_webhook = {
      method      = "POST"
      path        = "v1/webhooks/mercadopago"
      alb_path    = "/v1/webhooks/mercadopago"
      auth_roles  = []
      path_params = []
    }
  }

  # Helper function to normalize path by replacing all parameter placeholders with *
  # Example: "v1/orders/{orderId}" => "v1/orders/*"
  normalize_path_for_auth = {
    for key, route in local.api_routes :
    key => replace(route.path, "/\\{[^}]+\\}/", "*")
  }

  # Generate route_roles dynamically from api_routes
  # Only include routes that have auth_roles defined (non-empty)
  # Replace path parameters with * for authenticated routes
  route_roles = {
    for key, route in local.api_routes :
    "${route.method}:/${local.normalize_path_for_auth[key]}" => route.auth_roles
    if length(route.auth_roles) > 0
  }
}
