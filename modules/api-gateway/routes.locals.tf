locals {
  api_routes = {
    # Categories
    get_categories = {
      method      = "GET"
      path        = "v1/categories"
      alb_path    = "/v1/categories"
      path_params = []
    }

    get_categories_by_id = {
      method      = "GET"
      path        = "v1/categories/{categoryId}"
      alb_path    = "/v1/categories/{categoryId}"
      path_params = ["categoryId"]
    }

    create_category = {
      method      = "POST"
      path        = "v1/categories"
      alb_path    = "/v1/categories"
      path_params = []
    }

    update_category = {
      method      = "PUT"
      path        = "v1/categories/{categoryId}"
      alb_path    = "/v1/categories/{categoryId}"
      path_params = ["categoryId"]
    }

    delete_category = {
      method      = "DELETE"
      path        = "v1/categories/{categoryId}"
      alb_path    = "/v1/categories/{categoryId}"
      path_params = ["categoryId"]
    }

    # Products
    get_products_by_category = {
      method      = "GET"
      path        = "v1/products/category/{categoryId}"
      alb_path    = "/v1/products/category/{categoryId}"
      path_params = ["categoryId"]
    }

    get_product_by_id = {
      method      = "GET"
      path        = "v1/products/{productId}"
      alb_path    = "/v1/products/{productId}"
      path_params = ["productId"]
    }

    create_product = {
      method      = "POST"
      path        = "v1/products"
      alb_path    = "/v1/products"
      path_params = []
    }

    update_product = {
      method      = "PUT"
      path        = "v1/products/{productId}"
      alb_path    = "/v1/products/{productId}"
      path_params = ["productId"]
    }

    delete_product = {
      method      = "DELETE"
      path        = "v1/products/{productId}"
      alb_path    = "/v1/products/{productId}"
      path_params = ["productId"]
    }

    # Customers
    create_customer = {
      method      = "POST"
      path        = "v1/customers"
      alb_path    = "/v1/customers"
      path_params = []
    }

    # Employees
    create_employee = {
      method      = "POST"
      path        = "v1/employees"
      alb_path    = "/v1/employees"
      path_params = []
    }

    # Orders
    get_orders = {
      method      = "GET"
      path        = "v1/orders"
      alb_path    = "/v1/orders"
      path_params = []
    }

    get_active_orders = {
      method      = "GET"
      path        = "v1/orders/active"
      alb_path    = "/v1/orders/active"
      path_params = []
    }

    get_orders_by_id = {
      method      = "GET"
      path        = "v1/orders/{orderId}"
      alb_path    = "/v1/orders/{orderId}"
      path_params = ["orderId"]
    }

    create_order = {
      method      = "POST"
      path        = "v1/orders"
      alb_path    = "/v1/orders"
      path_params = []
    }

    add_combo_to_order = {
      method      = "POST"
      path        = "v1/orders/{orderId}/combos"
      alb_path    = "/v1/orders/{orderId}/combos"
      path_params = ["orderId"]
    }

    update_combo_from_order = {
      method      = "PUT"
      path        = "v1/orders/{orderId}/combos/{comboId}"
      alb_path    = "/v1/orders/{orderId}/combos/{comboId}"
      path_params = ["orderId", "comboId"]
    }

    delete_combo_from_order = {
      method      = "DELETE"
      path        = "v1/orders/{orderId}/combos/{comboId}"
      alb_path    = "/v1/orders/{orderId}/combos/{comboId}"
      path_params = ["orderId", "comboId"]
    }

    # Payments
    get_payment_by_id = {
      method      = "GET"
      path        = "v1/payments/{paymentId}"
      alb_path    = "/v1/payments/{paymentId}"
      path_params = ["paymentId"]
    }

    get_payment_by_order = {
      method      = "GET"
      path        = "v1/payments/orders/{orderId}"
      alb_path    = "/v1/payments/orders/{orderId}"
      path_params = ["orderId"]
    }

    # Webhook for MercadoPago
    mercadopago_webhook = {
      method      = "POST"
      path        = "v1/webhooks/mercadopago"
      alb_path    = "/v1/webhooks/mercadopago"
      path_params = []
    }
  }
}
