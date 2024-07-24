#!/bin/bash

# Stop and disable the systemd service
systemctl stop devopsfetch.service
systemctl disable devopsfetch.service

# Remove the systemd service file
rm /etc/systemd/system/devopsfetch.service

# Reload systemd
systemctl daemon-reload

# Remove the devopsfetch script
rm /usr/local/bin/devopsfetch

echo "DevOpsFetch has been uninstalled."
