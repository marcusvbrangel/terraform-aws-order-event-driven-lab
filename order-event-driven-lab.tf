# ============================================================
# ORDER EVENT DRIVEN LAB
#
# Primeira etapa:
#
# curl POST /orders
#        │
#        ▼
# API Gateway REST API
#        │
#        ▼
# SNS order-requested
#        │
#        ▼
# SQS order-service-queue
#
# Futuramente:
#
# SQS order-service
#        │
#        ▼
# Lambda Order Service
#        │
#        ├── DynamoDB
#        │
#        └── SNS Order Received
#                 │
#                 ├── SQS Payment
#                 └── SQS Inventory
#
# Payment SUCCESS + Inventory SUCCESS
#                 │
#                 ▼
#             coordenação
#                 │
#                 ▼
#          SQS Fulfilment
# ============================================================


# ============================================================
# SNS - ORDER REQUESTED
# ============================================================

resource "aws_sns_topic" "order_requested" {
  name = "order-requested"
}


# ============================================================
# SQS - ORDER SERVICE
# ============================================================

resource "aws_sqs_queue" "order_service" {
  name = "order-service-queue"
}


# ============================================================
# SNS -> SQS SUBSCRIPTION
# ============================================================

resource "aws_sns_topic_subscription" "order_service" {
  topic_arn = aws_sns_topic.order_requested.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.order_service.arn
}


# ============================================================
# SQS POLICY
#
# Permite SOMENTE ao SNS order-requested enviar mensagens
# para order-service-queue.
# ============================================================

resource "aws_sqs_queue_policy" "order_service" {
  queue_url = aws_sqs_queue.order_service.url

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "sns.amazonaws.com"
        }

        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.order_service.arn

        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_requested.arn
          }
        }
      }
    ]
  })
}


# ============================================================
# API GATEWAY REST API
#
# IMPORTANTE:
#
# Estamos usando REST API (v1), e NÃO HTTP API (v2).
#
# Motivo:
# queremos integração direta:
#
# API Gateway -> SNS Publish
# ============================================================

resource "aws_api_gateway_rest_api" "orders" {
  name = "orders-api"
}


# ============================================================
# RESOURCE /orders
# ============================================================

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_rest_api.orders.root_resource_id
  path_part   = "orders"
}


# ============================================================
# POST /orders
# ============================================================

resource "aws_api_gateway_method" "create_order" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders.id

  http_method   = "POST"
  authorization = "NONE"
}


# ============================================================
# IAM ROLE
#
# API Gateway poderá assumir esta role.
# ============================================================

resource "aws_iam_role" "api_gateway_sns" {
  name = "api-gateway-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "apigateway.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


# ============================================================
# IAM PERMISSION POLICY
#
# A role poderá SOMENTE publicar no tópico order-requested.
# ============================================================

resource "aws_iam_role_policy" "api_gateway_sns" {
  name = "api-gateway-sns-policy"
  role = aws_iam_role.api_gateway_sns.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.order_requested.arn
      }
    ]
  })
}


# ============================================================
# API GATEWAY -> SNS
#
# REST API utiliza integração AWS.
#
# O JSON recebido em POST /orders será transformado em uma
# chamada SNS Publish.
# ============================================================

resource "aws_api_gateway_integration" "order_requested_sns" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.create_order.http_method

  type                    = "AWS"
  integration_http_method = "POST"

  uri = "arn:aws:apigateway:us-east-1:sns:path//"

  credentials = aws_iam_role.api_gateway_sns.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=Publish&TopicArn=$util.urlEncode('${aws_sns_topic.order_requested.arn}')&Message=$util.urlEncode($input.body)"
  }

  passthrough_behavior = "NEVER"
}


# ============================================================
# METHOD RESPONSE
#
# Define a resposta HTTP que POST /orders poderá retornar.
# ============================================================

resource "aws_api_gateway_method_response" "create_order_200" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.create_order.http_method

  status_code = "200"
}


# ============================================================
# INTEGRATION RESPONSE
#
# Converte a resposta de sucesso do SNS para HTTP 200.
# ============================================================

resource "aws_api_gateway_integration_response" "create_order_200" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.create_order.http_method

  status_code = aws_api_gateway_method_response.create_order_200.status_code

  depends_on = [
    aws_api_gateway_integration.order_requested_sns
  ]
}


# ============================================================
# DEPLOYMENT
#
# REST API precisa ser implantada antes de poder ser chamada.
# ============================================================

resource "aws_api_gateway_deployment" "orders" {
  rest_api_id = aws_api_gateway_rest_api.orders.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_method.create_order.id,
      aws_api_gateway_integration.order_requested_sns.id,
      aws_api_gateway_method_response.create_order_200.id,
      aws_api_gateway_integration_response.create_order_200.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}


# ============================================================
# STAGE
#
# URL ficará:
#
# https://<api-id>.execute-api.us-east-1.amazonaws.com/lab/orders
# ============================================================

resource "aws_api_gateway_stage" "lab" {
  deployment_id = aws_api_gateway_deployment.orders.id
  rest_api_id   = aws_api_gateway_rest_api.orders.id

  stage_name = "lab"
}


# ============================================================
# OUTPUT
# ============================================================

output "orders_api_url" {
  value = "https://${aws_api_gateway_rest_api.orders.id}.execute-api.us-east-1.amazonaws.com/${aws_api_gateway_stage.lab.stage_name}/orders"
}
