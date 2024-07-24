#!/bin/bash

# Copy devopsfetch script to /usr/local/bin
cp devopsfetch.sh /usr/local/bin/devopsfetch
chmod +x /usr/local/bin/devopsfetch

# Create systemd service file
cat <<EOT > /etc/systemd/system/devopsfetch.service
[Unit]
Description=DevOpsFetch Service
After=network.target

[Service]
ExecStart=/usr/local/bin/devopsfetch -p
Restart=always
User=root
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=devopsfetch

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable devopsfetch.service
systemctl start devopsfetch.service

echo "DevOpsFetch has been installed and the service is running."
