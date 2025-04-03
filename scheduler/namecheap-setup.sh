#!/bin/bash

VPN_PROJECT_ROOT="$HOME/apps/vpn"
VPN_SCHEDULER_ROOT="$VPN_PROJECT_ROOT/scheduler"

# Step 1: Place your files
sudo cp "$VPN_PROJECT_ROOT/namecheap-ddns.sh" /usr/local/bin/
sudo cp "$VPN_PROJECT_ROOT/.env" /usr/local/bin/.env
sudo chmod +x /usr/local/bin/namecheap-ddns.sh

# Step 2: Create the environment file
sudo cp "$VPN_PROJECT_ROOT/.env" /etc/namecheap-ddns.env
sudo chmod 600 /etc/namecheap-ddns.env

# Step 3: Install the service and timer
sudo cp "$VPN_SCHEDULER_ROOT/namecheap-ddns.service" /etc/systemd/system/
sudo cp "$VPN_SCHEDULER_ROOT/namecheap-ddns.timer" /etc/systemd/system/

# Step 4: Reload systemd, enable and start timer
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now namecheap-ddns.timer
