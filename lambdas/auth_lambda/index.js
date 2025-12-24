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
  const arnParts = methodArn.split(':')
  const apiGatewayArn = arnParts[5].split('/')
  const method = apiGatewayArn[1]
  const path = '/' + apiGatewayArn.slice(2).join('/')
  return { method, path }
}

const normalizePath = (path) => {
  const segments = path.split('/').filter(seg => seg !== '')

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

  const exactKey = `${method}:${path}`
  if (routeRoles[exactKey]) {
    return routeRoles[exactKey]
  }

  const normalizedKey = getRouteKey(method, path)
  if (routeRoles[normalizedKey]) {
    return routeRoles[normalizedKey]
  }

  for (const [routePattern, requiredRole] of Object.entries(routeRoles)) {
    const [patternMethod, patternPath] = routePattern.split(':')
    
    if (patternMethod !== method) {
      continue
    }

    const regexPattern = patternPath
      .replace(/\*/g, '[^/]*')  
      .replace(/\//g, '\\/')
    
    if (patternPath.endsWith('/*')) {
      const prefix = patternPath.slice(0, -2) 
      if (path.startsWith(prefix + '/')) {
        return requiredRole
      }
    } else {
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

    const userRole = decoded.role
    if (!userRole) {
      throw new Error('Unauthorized - Role not found in token')
    }

    let routeRoles = {}
    if (process.env.ROUTE_ROLES) {
      try {
        routeRoles = JSON.parse(process.env.ROUTE_ROLES)
      } catch (parseError) {
        console.error('Error parsing ROUTE_ROLES:', parseError)
      }
    }

    const { method, path } = parseMethodArn(event.methodArn)

    const requiredRole = getRequiredRole(method, path, routeRoles)

    if (requiredRole && requiredRole !== userRole) {
      console.log(`Access denied: Route requires '${requiredRole}' but user has '${userRole}'`)
      throw new Error('Unauthorized - Insufficient permissions')
    }

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
