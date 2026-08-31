#!/bin/bash
# Generate self-signed TLS certificate for Gateway API
# This script creates a self-signed certificate valid for the server's IP and common hostnames

NAMESPACE="nginx-gateway"
SECRET_NAME="gateway-tls"
DAYS=3650

# Get the server's IP addresses
HOSTNAMES=("localhost" "devplatform01" "*.hobbymusik.net" "*.local")

# Generate a self-signed certificate
openssl req -x509 -nodes -days $DAYS -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=devplatform01/O=Dev Platform/C=US" \
  -addext "subjectAltName=DNS:localhost,DNS:devplatform01,DNS:*.hobbymusik.net,DNS:*.local,IP:127.0.0.1"

# Create Kubernetes secret
kubectl create secret tls $SECRET_NAME --namespace=$NAMESPACE \
  --cert=tls.crt --key=tls.key --dry-run=client -o yaml > tls-certificate.yaml

# Clean up temporary files
rm -f tls.key tls.crt

echo "TLS certificate generated in tls-certificate.yaml"
