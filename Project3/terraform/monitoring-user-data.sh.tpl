#!/bin/bash
set -e

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

mkdir -p /opt/monitoring
cd /opt/monitoring

cat <<'EOL' > docker-compose.yml
version: '3.7'
services:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "4000:4000"
EOL

cat <<'EOL' > prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node_exporter_metrics'
    static_configs:
      - targets: ['${web_app_private_ip}:9100']
EOL

sudo docker compose up -d
