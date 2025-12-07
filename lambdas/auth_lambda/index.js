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

exports.handler = async (event) => {
  try {
    const token = getToken(event)

    if (!token) {
      throw new Error('Unauthorized - No token provided')
    }

    const secret = await getSecret(process.env.JWT_SECRET_NAME)
    const decoded = jwt.verify(token, secret, { algorithms: ["HS256"] })

    const policy = generatePolicy(
      decoded.sub.toString(),
      'Allow',
      event.methodArn,
      {
        userId: decoded.sub.toString(),
        cpf: decoded.cpf,
        name: decoded.name,
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
