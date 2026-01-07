locals {
  path_level_0 = {
    for k, v in local.unique_path_segments :
    k => v
    if v.index == 0
  }

  path_level_1 = {
    for k, v in local.unique_path_segments :
    k => v
    if v.index == 1
  }

  path_level_2 = {
    for k, v in local.unique_path_segments :
    k => v
    if v.index == 2
  }

  path_level_3 = {
    for k, v in local.unique_path_segments :
    k => v
    if v.index == 3
  }

  path_level_4 = {
    for k, v in local.unique_path_segments :
    k => v
    if v.index == 4
  }

  route_keys = {
    for k, r in local.api_routes :
    k => "${r.method}:/${r.path}"
  }

  # Determine if each route requires authentication based on route_roles
  route_auth = {
    for k, route in local.api_routes :
    k => try(
      element([
        for rule, role in var.route_roles :
        role
        if startswith(local.route_keys[k], replace(rule, "*", ""))
      ], 0),
      null
    )
  }

  # Generate all path segments for API Gateway resources
  # Example: for path "v1/orders/{orderId}", it generates:
  # - "v1"
  # - "v1/orders"
  # - "v1/orders/{orderId}"
  path_segments = flatten([
    for route in local.api_routes : [
      for idx, part in split("/", route.path) : {
        full_path = join("/", slice(split("/", route.path), 0, idx + 1))
        parent    = idx == 0 ? null : join("/", slice(split("/", route.path), 0, idx))
        part      = part
        index     = idx
      }
    ]
  ])

  # Group path segments by their full path to handle duplicates
  grouped_path_segments = {
    for p in local.path_segments :
    p.full_path => p...
  }

  # Make path segments unique to avoid duplicate resources
  unique_path_segments = {
    for path, segments in local.grouped_path_segments :
    path => segments[0]
  }

  # Merge all levels of API Gateway resources into a single map
  api_gateway_resources = merge(
    aws_api_gateway_resource.level_0,
    aws_api_gateway_resource.level_1,
    aws_api_gateway_resource.level_2,
    aws_api_gateway_resource.level_3,
    aws_api_gateway_resource.level_4
  )
}
