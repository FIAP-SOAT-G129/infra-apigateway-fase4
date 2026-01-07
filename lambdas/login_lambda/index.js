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

const createToken = async (name, cpf, email, role) => {
  const secret = await getSecret(process.env.JWT_SECRET_NAME)

  console.log('createToken', name, cpf, email, role)
  const token = jwt.sign(
    {
      cpf, email, role, name,
      sub: cpf || email,
      iat: Math.floor(Date.now() / 1000)
    },
    secret,
    {
      algorithm: "HS256",
      expiresIn: "1h"
    }
  )
  console.log('token', token)

  return token
}

const fetchCustomerByCpf = async (cpf) => {
  console.log('fetchCustomerByCpf', cpf)

  if (!cpf || cpf.length !== 11) {
    return null
  }

  try {
    const lbDnsName = process.env.LB_DNS_NAME
    if (!lbDnsName) {
      console.error('LB_DNS_NAME environment variable is not set')
      return null
    }

    const url = `http://${lbDnsName}/v1/customers/${cpf}`
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

const fetchEmployeeByEmail = async (email) => {
  console.log('fetchEmployeeByEmail', email)

  if (!email || !email.includes('@')) {
    return null
  }

  try {
    const lbDnsName = process.env.LB_DNS_NAME
    if (!lbDnsName) {
      console.error('LB_DNS_NAME environment variable is not set')
      return null
    }

    const url = `http://${lbDnsName}/v1/employees/${email}`
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

    const employee = await response.json()
    console.log('Employee data received:', employee)

    return employee

  } catch (error) {
    console.error('Error fetching employee:', error.message)
    return null
  }
}

exports.handler = async (event) => {
  try {
    const body = event.isBase64Encoded ?
      Buffer.from(event.body, 'base64').toString() :
      event.body

    const { cpf, email } = JSON.parse(body || "{}")

    if (!cpf && !email) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify({
          error: "CPF ou Email é obrigatório",
          message: "Campo 'cpf' ou 'email' deve ser fornecido no body da requisição"
        })
      }
    }

    if (cpf) {
      const customer = await fetchCustomerByCpf(cpf)

      if (!customer) {
        return {
          statusCode: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          },
        }
      }

      const token = await createToken(customer.name, customer.cpf, customer.email, 'customer')

      const response = {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify({
          token,
          customer,
          role: 'customer',
          expiresIn: "1h"
        })
      }

      return response
    }

    const employee = await fetchEmployeeByEmail(email)
    if (!employee) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
      }
    }

    console.log('employee', employee)
    const token = createToken(employee.name, null, employee.email, 'employee')

    const response = {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
      body: JSON.stringify({
        token,
        employee,
        role: 'employee',
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