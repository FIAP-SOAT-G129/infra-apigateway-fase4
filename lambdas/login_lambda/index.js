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

const fetchCustomerByCpf = async (cpf) => {
  console.log('fetchCustomerByCpf', cpf)

  if (!cpf || cpf.length !== 11) {
    return null
  }

  try {
    const nlbDnsName = process.env.NLB_DNS_NAME
    const nlbPort = process.env.NLB_PORT || "30080"

    if (!nlbDnsName) {
      console.error('NLB_DNS_NAME environment variable is not set')
      return null
    }

    const url = `http://${nlbDnsName}:${nlbPort}/v1/customers/${cpf}`
    console.log('Making request to:', url)

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      console.error(`HTTP error! status: ${response.status}`)
      return null
    }

    const customer = await response.json()
    console.log('Customer data received:', customer)

    return customer

  } catch (error) {
    console.error('Error fetching customer:', error.message)
    return null
  }
}

exports.handler = async (event) => {
  try {
    const body = event.isBase64Encoded ?
      Buffer.from(event.body, 'base64').toString() :
      event.body

    const { cpf } = JSON.parse(body || "{}")

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

    const customer = await fetchCustomerByCpf(cpf)

    if (!customer) {
      return {
        statusCode: 404,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify({
          error: "Customer não encontrado",
          message: `Nenhum customer encontrado para o CPF: ${cpf}`
        })
      }
    }

    const secret = await getSecret(process.env.JWT_SECRET_NAME)

    const token = jwt.sign(
      {
        sub: customer.id,
        cpf: customer.cpf,
        name: customer.name,
        email: customer.email,
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
        customer: {
          id: customer.id,
          name: customer.name,
          cpf: customer.cpf
        },
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