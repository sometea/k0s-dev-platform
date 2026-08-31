#!/bin/bash

# Update the operating system
# apt update && apt upgrade -y

# # Install postgresql and podman
# apt install -y postgresql postgresql-contrib podman

# # Enable unattended-upgrades
# apt install -y unattended-upgrades
# systemctl enable --now unattended-upgrades

# Edit postgresql.conf to allow local connections
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf
# Edit pg_hba.conf to allow remote connections
echo "host    all             all       0.0.0.0/0       md5" >> /etc/postgresql/16/main/pg_hba.conf
systemctl restart postgresql

# Create Postgres user and database
sudo -u postgres psql -c "CREATE USER strapi WITH PASSWORD 'strapi';"
sudo -u postgres psql -c "CREATE DATABASE strapi OWNER strapi;"
sudo -u postgres psql -d strapi -c "GRANT ALL ON SCHEMA public TO strapi;"

# Set up a data directory for local volumes
mkdir -p /var/data

# Install and setup k0s
curl -sSf https://get.k0s.sh | sh
k0s install controller --single
k0s start

# wait for k0s to be ready
while ! k0s status | grep -q "Kube-api probing successful: true"; do
    echo "Waiting for k0s to be ready..."
    sleep 5
done

# Wait for Gateway API CRDs to be ready
sleep 10

# Install NGINX Gateway Fabric
k0s kubectl create namespace nginx-gateway
k0s kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.7" | k0s kubectl apply -f -
k0s kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.6.7/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.6.7/deploy/nodeport/deploy.yaml

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
      {"name": "port-80", "port": 80, "targetPort": 80, "nodePort": 3080},
      {"name": "port-443", "port": 443, "targetPort": 443, "nodePort": 3443},
      {"name": "metrics", "port": 9113, "targetPort": 9113}
    ]
  }
}'

# Apply Gateway configuration
k0s kubectl apply -f workloads/gateway

# Generate and apply TLS certificate for Gateway
./generate-tls-cert.sh
k0s kubectl apply -f tls-certificate.yaml

# Install CSI local path provisionier
k0s kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
k0s kubectl apply -f workloads/storage/

# Install the Sealed Secrets controller
k0s kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.34.0/controller.yaml

# Apply the workloads
k0s kubectl apply -f workloads/postgres-service
k0s kubectl apply -f workloads/storage
k0s kubectl apply -f workloads/beamtime
k0s kubectl apply -f workloads/demo
k0s kubectl apply -f workloads/fluffybunnyadventures
k0s kubectl apply -f workloads/hobbymusik
k0s kubectl apply -f workloads/strapi


