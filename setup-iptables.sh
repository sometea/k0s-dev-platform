#!/bin/bash

# This script must be run as root to set up port forwarding using ufw
# from standard ports (80, 443) to NodePorts (30080, 30443)

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Set up port forwarding rules using ufw
# First, allow the NodePorts through ufw
ufw allow 30080/tcp
ufw allow 30443/tcp

# Add port forwarding rules before the ufw rules
# We need to use iptables directly for the NAT rules
# Insert rules at the beginning of the PREROUTING chain to ensure they're processed first
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-port 30080
iptables -t nat -I PREROUTING 2 -p tcp --dport 443 -j REDIRECT --to-port 30443

# Save iptables rules to ufw's before.rules to make them persistent
# This ensures the NAT rules are loaded before ufw's own rules
if [ -f /etc/ufw/before.rules ]; then
    # Backup existing before.rules
    cp /etc/ufw/before.rules /etc/ufw/before.rules.bak
    
    # Add NAT rules to before.rules
    echo "" >> /etc/ufw/before.rules
    echo "# Port forwarding for k0s NodePorts" >> /etc/ufw/before.rules
    echo "*nat" >> /etc/ufw/before.rules
    echo ":PREROUTING ACCEPT [0:0]" >> /etc/ufw/before.rules
    echo "-A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 30080" >> /etc/ufw/before.rules
    echo "-A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 30443" >> /etc/ufw/before.rules
    echo "COMMIT" >> /etc/ufw/before.rules
fi

# Reload ufw to apply changes
ufw reload

echo "Port forwarding rules set up using ufw:"
echo "  80 -> 30080 (HTTP)"
echo "  443 -> 30443 (HTTPS)"

# Display current NAT rules
echo -e "\nCurrent NAT rules:"
iptables -t nat -L -n -v

# Display ufw status
echo -e "\nUFW status:"
ufw status verbose