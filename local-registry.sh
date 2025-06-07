#!/bin/bash

# Ensure the systemd integration directory exists
mkdir -p /etc/containers/systemd

# Ensure data directory for the registry exists
mkdir -p /var/lib/registry

cp registry.container /etc/containers/systemd/

# Enable the local registry service
systemctl daemon-reexec
systemctl daemon-reload
systemctl start registry
