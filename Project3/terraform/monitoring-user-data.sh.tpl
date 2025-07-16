#!/bin/bash

# Update and install required packages
sudo apt update -y
sudo apt install -y docker.io docker-compose unzip wget curl

# Start and enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Install and start SSM agent
sudo snap install amazon-ssm-agent --classic
sudo systemctl enable amazon-ssm-agent
sudo systemctl restart amazon-ssm-agent || sudo systemctl start amazon-ssm-agent

# Add Ubuntu user to Docker group
sudo usermod -aG docker ubuntu

# Create monitoring folder structure
mkdir -p /opt/monitoring
cd /opt/monitoring

# Replace this with the actual private IP of the web app (e.g., 10.0.1.10)
WEB_APP_IP="10.0.1.10"

# Prometheus config
cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: "node_exporter_metrics"
    static_configs:
      - targets: ["${WEB_APP_IP}:9100"]
EOF

# Prometheus alerting rules
cat <<EOF > alerts.yml
groups:
  - name: instance-down
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ \$labels.instance }} is down"
          description: "{{ \$labels.instance }} has been unreachable for 1 minute."
EOF

# Grafana provisioning
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/provisioning/datasources
mkdir -p dashboards

# Grafana data source config
cat <<EOF > grafana/provisioning/datasources/datasource.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

# Grafana dashboard provisioning
cat <<EOF > grafana/provisioning/dashboards/dashboard.yml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOF

# Download node exporter dashboard
wget -O dashboards/node_exporter_full.json https://grafana.com/api/dashboards/1860/revisions/33/download

# Docker Compose stack
cat <<EOF > docker-compose.yml
version: "3"
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts.yml:/etc/prometheus/alerts.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./dashboards:/var/lib/grafana/dashboards

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.14.0
    environment:
      - discovery.type=single-node
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:8.14.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
EOF

# Start the monitoring stack
docker compose up -d
