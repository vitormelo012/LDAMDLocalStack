#!/bin/bash

echo "Inicializando bucket S3..."

# Criar o bucket shopping-images
awslocal s3 mb s3://shopping-images

# Configurar política pública para o bucket (opcional, para testes)
awslocal s3api put-bucket-acl --bucket shopping-images --acl public-read

echo "Bucket 'shopping-images' criado com sucesso!"

# Listar buckets para confirmar
awslocal s3 ls
