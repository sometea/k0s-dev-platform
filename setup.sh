#!/bin/bash

# Update the operating system
# apt update && apt upgrade -y

# # Install postgresql and podman
# apt install -y postgresql postgresql-contrib podman

# # Enable unattended-upgrades
# apt install -y unattended-upgrades
# systemctl enable --now unattended-upgrades

# Create Postgres user and database
sudo -u postgres psql -c "CREATE USER strapi WITH PASSWORD 'strapi';"
sudo -u postgres psql -c "CREATE DATABASE strapi OWNER strapi;"

# Install and setup k0s
curl -sSf https://get.k0s.sh | sudo sh
sudo k0s install controller --single
sudo k0s start

# wait for k0s to be ready
while ! sudo k0s status | grep -q "k0s is running"; do
    echo "Waiting for k0s to be ready..."
    sleep 5
done

# Install NGINX ingress controller
sudo k0s kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.3/deploy/static/provider/baremetal/deploy.yaml

# Wait for NGINX ingress controller to be ready
while ! sudo k0s kubectl get pods -n ingress-nginx | grep -q "1/1"; do
    echo "Waiting for NGINX ingress controller to be ready..."
    sleep 5
done

sudo k0s kubectl -n ingress-nginx annotate ingressclasses nginx ingressclass.kubernetes.io/is-default-class="true"

