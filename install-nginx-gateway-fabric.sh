#!/bin/bash


# Install NGINX Gateway Fabric
k0s kubectl create namespace nginx-gateway
k0s kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.7" | k0s kubectl apply -f -
sleep 10
k0s kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.6.7/deploy/crds.yaml
k0s kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.6.7/deploy/nodeport/deploy.yaml

# Wait for NGINX Gateway Fabric to be ready
while ! k0s kubectl get pods -n nginx-gateway | grep -q "1/1"; do
    echo "Waiting for NGINX Gateway Fabric to be ready..."
    sleep 5
done

# Patch the service to use custom NodePorts (3080 for HTTP, 3443 for HTTPS)
k0s kubectl patch svc -n nginx-gateway nginx-gateway-nginx -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {"name": "port-80", "port": 80, "targetPort": 80, "nodePort": 30080},
      {"name": "port-443", "port": 443, "targetPort": 443, "nodePort": 30443},
      {"name": "metrics", "port": 9113, "targetPort": 9113}
    ]
  }
}'

# Apply Gateway configuration
k0s kubectl apply -f workloads/gateway

# Generate and apply TLS certificate for Gateway
./generate-tls-cert.sh
k0s kubectl apply -f tls-certificate.yaml
