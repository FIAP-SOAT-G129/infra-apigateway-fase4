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

exports.handler = async (event) => {
  try {
    const body = event.isBase64Encoded ?
      Buffer.from(event.body, 'base64').toString() :
      event.body

    const { cpf, role, name } = JSON.parse(body || "{}")

    if (!cpf) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify({
          error: "CPF é obrigatório",
          message: "Campo 'cpf' deve ser fornecido no body da requisição"
        })
      }
    }

    if (!role) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify({
          error: "Role é obrigatório",
          message: "Campo 'role' deve ser fornecido no body da requisição"
        })
      }
    }

    if (role !== "customer" && role !== "employee") {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify({
          error: "Role inválido",
          message: "Campo 'role' deve ser 'customer' ou 'employee'"
        })
      }
    }

    const secret = await getSecret(process.env.JWT_SECRET_NAME)

    const token = jwt.sign(
      {
        cpf, role, name,
        sub: cpf,
        iat: Math.floor(Date.now() / 1000)
      },
      secret,
      {
        algorithm: "HS256",
        expiresIn: "1h"
      }
    )

    const response = {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
      body: JSON.stringify({
        token,
        cpf: cpf,
        role: role,
        expiresIn: "1h"
      })
    }

    return response

  } catch (err) {
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
      body: JSON.stringify({
        error: "Erro interno do servidor",
        message: err.message
      })
    }
  }
}