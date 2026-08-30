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

# Install Gateway API CRDs
k0s kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml

# Wait for Gateway API CRDs to be ready
sleep 10

# Install NGINX Gateway Fabric
k0s kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.4.0/manifests.yaml

# Patch the deployment to use hostNetwork for port 80/443 binding
k0s kubectl patch deployment -n nginx-gateway-fabric nginx-gateway-fabric --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true}]'

k0s kubectl patch deployment -n nginx-gateway-fabric nginx-gateway-fabric --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/dnsPolicy", "value": "ClusterFirstWithHostNet"}]'

# Wait for NGINX Gateway Fabric to be ready
while ! k0s kubectl get pods -n nginx-gateway-fabric | grep -q "1/1"; do
    echo "Waiting for NGINX Gateway Fabric to be ready..."
    sleep 5
done

# Apply Gateway configuration
k0s kubectl apply -f gateway-class.yaml
k0s kubectl apply -f gateway.yaml

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


