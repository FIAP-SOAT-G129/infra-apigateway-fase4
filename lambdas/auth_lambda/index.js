const jwt = require("jsonwebtoken")
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager")

const sm = new SecretsManagerClient()

const getSecret = async (name) => {
  try {
    const res = await sm.send(new GetSecretValueCommand({ SecretId: name }))
    const secretData = JSON.parse(res.SecretString)
    return secretData.jwt_secret
  } catch (error) {
    return process.env.JWT_SECRET || 'fallback-secret'
  }
}

const generatePolicy = (principalId, effect, resource, context = {}) => {
  return {
    principalId,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resource
        }
      ]
    },
    context
  }
}

const getToken = (event) => {
  let token = null

  if (event.type === 'TOKEN') {
    token = event.authorizationToken
    if (token && token.startsWith('Bearer ')) {
      token = token.substring(7)
    }
  } else {
    const authHeader = event.headers?.Authorization ||
      event.headers?.authorization ||
      event.headers?.AUTHORIZATION || ""

    if (authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7)
    }

    if (!token && event.body) {
      const body = typeof event.body === "string" ?
        JSON.parse(event.body) :
        (event.body || {})
      token = body.token
    }

    if (!token && event.queryStringParameters) {
      token = event.queryStringParameters.token
    }
  }
  return token
}

const parseMethodArn = (methodArn) => {
  // Format: arn:aws:execute-api:region:account-id:api-id/stage/METHOD/path
  const arnParts = methodArn.split(':')
  const apiGatewayArn = arnParts[5].split('/')
  const method = apiGatewayArn[1]
  const path = '/' + apiGatewayArn.slice(2).join('/')
  return { method, path }
}

const normalizePath = (path) => {
  // Replace path parameters and IDs with wildcards for pattern matching
  // e.g., /v1/orders/customers/123 -> /v1/orders/customers/*
  // e.g., /v1/products/abc123 -> /v1/products/*
  
  // Split path into segments
  const segments = path.split('/').filter(seg => seg !== '')
  
  // Replace segments that look like IDs (numeric, UUID, or long alphanumeric) with *
  const normalizedSegments = segments.map(seg => {
    if (/^\d+$/.test(seg) || 
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(seg) ||
        (seg.length > 10 && /^[a-zA-Z0-9]+$/.test(seg))) {
      return '*'
    }
    return seg
  })
  
  return '/' + normalizedSegments.join('/')
}

const getRouteKey = (method, path) => {
  const normalized = normalizePath(path)
  return `${method}:${normalized}`
}

const getRequiredRole = (method, path, routeRoles) => {
  if (!routeRoles || Object.keys(routeRoles).length === 0) {
    return null
  }

  // Try exact match first
  const exactKey = `${method}:${path}`
  if (routeRoles[exactKey]) {
    return routeRoles[exactKey]
  }

  // Try normalized path (with IDs replaced by *)
  const normalizedKey = getRouteKey(method, path)
  if (routeRoles[normalizedKey]) {
    return routeRoles[normalizedKey]
  }

  // Try pattern matching with wildcards
  // Match patterns like "GET:/v1/orders/*" against actual paths like "/v1/orders/customers/123"
  for (const [routePattern, requiredRole] of Object.entries(routeRoles)) {
    const [patternMethod, patternPath] = routePattern.split(':')
    
    if (patternMethod !== method) {
      continue
    }

    // Convert pattern to regex (replace * with .* and escape other chars)
    // Pattern "/v1/orders/*" should match "/v1/orders/customers/123"
    const regexPattern = patternPath
      .replace(/\*/g, '[^/]*')  // Match any characters except / for a single segment
      .replace(/\//g, '\\/')
    
    // If pattern ends with /*, it should match the path prefix
    if (patternPath.endsWith('/*')) {
      const prefix = patternPath.slice(0, -2) // Remove trailing /*
      if (path.startsWith(prefix + '/')) {
        return requiredRole
      }
    } else {
      // Exact match with wildcards
      const regex = new RegExp(`^${regexPattern}$`)
      if (regex.test(path)) {
        return requiredRole
      }
    }
  }

  return null
}

exports.handler = async (event) => {
  try {
    const token = getToken(event)

    if (!token) {
      throw new Error('Unauthorized - No token provided')
    }

    const secret = await getSecret(process.env.JWT_SECRET_NAME)
    const decoded = jwt.verify(token, secret, { algorithms: ["HS256"] })

    // Extract role from JWT
    const userRole = decoded.role
    if (!userRole) {
      throw new Error('Unauthorized - Role not found in token')
    }

    // Get route-to-role mapping from environment variable
    let routeRoles = {}
    if (process.env.ROUTE_ROLES) {
      try {
        routeRoles = JSON.parse(process.env.ROUTE_ROLES)
      } catch (parseError) {
        console.error('Error parsing ROUTE_ROLES:', parseError)
        // Continue with empty mapping (bypass role check)
      }
    }

    // Parse methodArn to get method and path
    const { method, path } = parseMethodArn(event.methodArn)

    // Get required role for this route
    const requiredRole = getRequiredRole(method, path, routeRoles)

    // If route requires a specific role, check if user's role matches
    if (requiredRole && requiredRole !== userRole) {
      console.log(`Access denied: Route requires '${requiredRole}' but user has '${userRole}'`)
      throw new Error('Unauthorized - Insufficient permissions')
    }

    // Generate policy with user context
    const policy = generatePolicy(
      decoded.sub.toString(),
      'Allow',
      event.methodArn,
      {
        userId: decoded.sub.toString(),
        cpf: decoded.cpf || '',
        role: userRole,
        name: decoded.name || '',
        email: decoded.email || ''
      }
    )

    return policy

  } catch (error) {
    console.error('Authorization failed:', {
      error: error.message,
      stack: error.stack,
      eventType: event.type,
      methodArn: event.methodArn
    })

    throw new Error('Unauthorized')
  }
}
