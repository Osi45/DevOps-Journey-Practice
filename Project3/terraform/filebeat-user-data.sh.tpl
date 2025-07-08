#!/bin/bash

sudo apt update -y
sudo apt install -y wget curl unzip snapd

sudo snap install amazon-ssm-agent --classic
sudo systemctl enable amazon-ssm-agent
sudo systemctl restart amazon-ssm-agent || sudo systemctl start amazon-ssm-agent

sudo useradd -rs /bin/false node_exporter
cd /opt
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.8.1.linux-amd64.tar.gz
sudo cp node_exporter-1.8.1.linux-amd64/node_exporter /usr/local/bin/

cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.14.0-amd64.deb
sudo dpkg -i filebeat-8.14.0-amd64.deb

cat <<EOF | sudo tee /etc/filebeat/filebeat.yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/syslog
    - /var/log/auth.log

output.elasticsearch:
  hosts: ["http://${monitoring_private_ip}:9200"]

setup.kibana:
  host: "http://${monitoring_private_ip}:5601"

setup.dashboards.enabled: true

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
EOF

sudo systemctl enable filebeat
sudo systemctl start filebeat
