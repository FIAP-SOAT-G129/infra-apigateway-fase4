# 🚪 Infraestrutura do API Gateway

Este repositório contém a infraestrutura de API Gateway para o projeto Fastfood, provisionada via **Terraform** na AWS. Inclui:

- Amazon API Gateway (REST API)
- Funções Lambda (Login e Authorizer)
- Security Group dedicado
- Integração com **AWS Secrets Manager** para JWT
- Integração com Application Load Balancer (ALB)
- Backend remoto em S3

---

## 📦 Estrutura do Projeto

```text
infra-apigateway-fase4/
│── main.tf                # Configuração principal e orquestração dos módulos
│── variables.tf           # Variáveis globais do projeto
│── terraform.tfvars       # Valores das variáveis (exceto secrets)
│── providers.tf           # Providers necessários (AWS)
│── datasource.tf          # Data source para estados remotos
│── backend.tf             # Configuração do backend remoto S3
│── outputs.tf             # Saídas exportadas (API Gateway URL, Lambda names, etc)
│── lambdas/               # Código fonte das funções Lambda
│   ├── auth_lambda/       # Lambda Authorizer para autenticação JWT
│   └── login_lambda/      # Lambda para endpoint de login
│── modules/               # Módulos reutilizáveis
│   ├── api-gateway/       # Módulo de API Gateway
│   ├── lambda/            # Módulo de Lambda Functions
│   ├── security-group/    # Módulo de Security Group
│   └── secrets-manager/   # Módulo de Secrets Manager
```

---

## ⚙️ Pré-requisitos

- [Terraform >= 1.6](https://developer.hashicorp.com/terraform/downloads)
- AWS CLI configurado
- VPC e subnets privadas já provisionadas [infra-foundation-fase4](https://github.com/FIAP-SOAT-G129/infra-foundation-fase4)
- Application Load Balancer (ALB) já provisionado
- Secret JWT para autenticação (usuário/senha)

---

## 🚀 Como usar

### 1. Inicializar o Terraform

```bash
terraform init
```

### 2. Validar a configuração

```bash
terraform validate
```

### 3. Planejar alterações

```bash
terraform plan -var-file="terraform.tfvars" -var-file="secrets.tfvars"
```

### 4. Aplicar alterações

```bash
terraform apply -var-file="terraform.tfvars" -var-file="secrets.tfvars"
```

---

## 🔑 Backend remoto

O estado do Terraform (`terraform.tfstate`) é armazenado no bucket S3:

- **Bucket:** `fastfood-tf-states`
- **Folder:** `infra/lambda/`

A configuração completa está no arquivo `backend.tf`.

---

## 🔑 Gestão de credenciais

- O secret JWT é definido via **AWS Secrets Manager** (módulo `secrets-manager`).
- No pipeline, o secret é exportado para um arquivo `secrets.tfvars`, consumido pelo Terraform.
- Nunca armazene secrets diretamente no repositório.

Exemplo de `secrets.tfvars`:

```hcl
jwt_secret = "seu-jwt-secret-aqui"
```

---

## 📤 Outputs

Após aplicar, os principais outputs incluem:

- **api_gateway_invoke_url** → URL de invocação do API Gateway
- **api_gateway_id** → ID do API Gateway
- **lambda_login_function_name** → Nome da função Lambda de login
- **lambda_auth_function_name** → Nome da função Lambda de autenticação
- **alb_dns_name** → DNS name do ALB utilizado nas integrações

---

## 🏗️ Pipeline de Automação

O projeto utiliza pipelines CI/CD no GitHub Actions para garantir a automação, qualidade e segurança do provisionamento da infraestrutura. Os principais workflows estão em `.github/workflows/`:

- **fmt-validate.yml**: Executa `terraform fmt` e `terraform validate` em todos os PRs e pushes, garantindo que o código esteja formatado e válido antes de ser aplicado.

- **apply.yml**: Aplica as alterações aprovadas na infraestrutura (`terraform apply`) após revisão e aprovação do plano.

- **destroy.yml**: Automatiza a destruição dos recursos provisionados, geralmente utilizado para ambientes temporários ou de testes.
  
### Benefícios da automação

- Reduz erros manuais e aumenta a rastreabilidade
- Garante validação e revisão antes de qualquer alteração
- Permite auditoria e histórico de mudanças
- Facilita rollback e destruição controlada de recursos

Consulte cada arquivo em `.github/workflows/` para detalhes e personalizações.
