#!/usr/bin/env bash

API_URL="https://b1b7mkijz0.execute-api.us-east-1.amazonaws.com/lab/orders"

curl --request POST \
  --url "$API_URL" \
  --header "Content-Type: application/json" \
  --data '{
    "orderId": "ORDER-1001",
    "customer": {
      "id": "CUSTOMER-1001",
      "name": "Marcus Rangel",
      "email": "netmarvin@gmail.com",
      "phone": "+55-22-99999-9999"
    },
    "deliveryAddress": {
      "street": "Rua das Palmeiras",
      "number": "100",
      "complement": "Apto 201",
      "district": "Centro",
      "city": "Rio das Ostras",
      "state": "RJ",
      "zipCode": "28890-000",
      "country": "BR"
    },
    "items": [
      {
        "productId": "PRODUCT-001",
        "name": "Mechanical Keyboard",
        "quantity": 1,
        "unitPrice": 350.00
      },
      {
        "productId": "PRODUCT-002",
        "name": "Wireless Mouse",
        "quantity": 2,
        "unitPrice": 120.00
      },
      {
        "productId": "PRODUCT-003",
        "name": "USB-C Hub",
        "quantity": 1,
        "unitPrice": 180.00
      }
    ],
    "currency": "BRL",
    "totalAmount": 770.00
  }'

echo