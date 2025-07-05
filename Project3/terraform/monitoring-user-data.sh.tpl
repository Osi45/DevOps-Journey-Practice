#!/bin/bash
sudo apt update -y
sudo apt install -y docker.io docker-compose git

sudo systemctl enable docker
sudo systemctl start docker

mkdir -p /opt/monitoring
cd /opt/monitoring

cat <<EOL > docker-compose.yml
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

cat <<EOL > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter_metrics'
    static_configs:
      - targets: ['${web_app_private_ip}:9100']
EOL

sudo docker-compose up -d
