const jwt = require("jsonwebtoken");
const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");

const sm = new SecretsManagerClient();

const getSecret = async (name) => {
  try {
    const res = await sm.send(new GetSecretValueCommand({ SecretId: name }));
    const secretData = JSON.parse(res.SecretString);
    return secretData.jwt_secret;
  } catch (error) {
    console.error("Error getting secret:", error);
    return process.env.JWT_SECRET || "fallback-secret";
  }
};

const generatePolicy = (principalId, effect, resource, context = {}) => ({
  principalId,
  policyDocument: {
    Version: "2012-10-17",
    Statement: [
      {
        Action: "execute-api:Invoke",
        Effect: effect,
        Resource: resource,
      },
    ],
  },
  context,
});

const getToken = (event) => {
  let token = null;

  if (event.type === "TOKEN") {
    token = event.authorizationToken;
    if (token?.startsWith("Bearer ")) {
      token = token.substring(7);
    }
  } else {
    const authHeader =
      event.headers?.Authorization || event.headers?.authorization || "";

    if (authHeader.startsWith("Bearer ")) {
      token = authHeader.substring(7);
    }

    if (!token && event.body) {
      const body =
        typeof event.body === "string" ? JSON.parse(event.body) : event.body;
      token = body?.token;
    }

    if (!token && event.queryStringParameters) {
      token = event.queryStringParameters.token;
    }
  }
  return token;
};

const parseMethodArn = (methodArn) => {
  const arnParts = methodArn.split(":");
  const apiGatewayArn = arnParts[5].split("/");
  // Format: arn:aws:execute-api:region:account:api-id/stage/method/path
  // apiGatewayArn = [api-id, stage, method, path, segments...]
  const method = apiGatewayArn[2];
  const path = "/" + apiGatewayArn.slice(3).join("/");
  return { method, path };
};

const normalizePath = (path) => {
  const segments = path.split("/").filter(Boolean);

  const normalized = segments.map((seg) => {
    if (
      /^\d+$/.test(seg) || // numeric IDs
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        seg
      ) || // UUID
      (seg.length > 10 && /^[a-zA-Z0-9]+$/.test(seg)) // hash-like
    ) {
      return "*";
    }
    return seg;
  });
  return "/" + normalized.join("/");
};
const getRequiredRole = (method, path, routeRoles) => {
  if (!routeRoles || Object.keys(routeRoles).length === 0) {
    return null;
  }

  const normalizedPath = normalizePath(path);
  const normalizedKey = `${method}:${normalizedPath}`;

  // Check for normalized path first
  if (routeRoles[normalizedKey]) {
    return routeRoles[normalizedKey];
  }

  // Fallback to exact path match
  const exactKey = `${method}:${path}`;
  if (routeRoles[exactKey]) {
    return routeRoles[exactKey];
  }

  return null;
};

exports.handler = async (event) => {
  try {
    const token = getToken(event);
    if (!token) {
      throw new Error("Unauthorized - No token");
    }

    const secret = await getSecret(process.env.JWT_SECRET_NAME);
    const decoded = jwt.verify(token, secret, { algorithms: ["HS256"] });

    const userRole = decoded.role;
    if (!userRole) {
      throw new Error("Unauthorized - Role missing");
    }

    let routeRoles = {};
    if (process.env.ROUTE_ROLES) {
      routeRoles = JSON.parse(process.env.ROUTE_ROLES);
    }

    const { method, path } = parseMethodArn(event.methodArn);
    const requiredRoles = getRequiredRole(method, path, routeRoles);

    if (requiredRoles) {
      const rolesArray = Array.isArray(requiredRoles)
        ? requiredRoles
        : [requiredRoles];

      if (!rolesArray.includes(userRole)) {
        throw new Error("Unauthorized - Insufficient permissions");
      }
    }

    return generatePolicy(decoded.sub.toString(), "Allow", event.methodArn, {
      userId: decoded.sub.toString(),
      cpf: decoded.cpf || "",
      role: userRole,
      name: decoded.name || "",
      email: decoded.email || "",
    });
  } catch (error) {
    console.error("Authorization failed:", {
      message: error.message,
      methodArn: event.methodArn,
    });

    throw new Error("Unauthorized");
  }
};
