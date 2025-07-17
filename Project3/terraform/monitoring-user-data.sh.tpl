#!/bin/bash

# Update and install required packages
sudo apt update -y
sudo apt install -y docker.io unzip wget curl 

# Start and enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Install and enable SSM agent
sudo snap install amazon-ssm-agent --classic
sudo systemctl enable amazon-ssm-agent
sudo systemctl restart amazon-ssm-agent || sudo systemctl start amazon-ssm-agent

# Add Ubuntu user to Docker group
sudo usermod -aG docker ubuntu

# Create monitoring folder structure
mkdir -p /opt/monitoring
cd /opt/monitoring

# Prometheus config
cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

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

      - alert: HighCPUUsage
        expr: 100 - (avg by (instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ \$labels.instance }}"
          description: "{{ \$labels.instance }} CPU usage is above 80%."

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High Memory usage on {{ \$labels.instance }}"
          description: "{{ \$labels.instance }} memory usage is above 80%."

      - alert: LowDiskSpace
        expr: (node_filesystem_size_bytes{fstype!~"tmpfs|overlay"} - node_filesystem_free_bytes{fstype!~"tmpfs|overlay"}) / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"} * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ \$labels.instance }}"
          description: "{{ \$labels.instance }} disk usage is above 80%."

EOF

# Alertmanager config with Slack
cat <<EOF > alertmanager.yml
global:
  resolve_timeout: 5m

route:
  receiver: 'slack-notifications'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - send_resolved: true
        token: '\${SLACK_BOT_TOKEN}'
        channel: '\${SLACK_CHANNEL_ID

EOF

# Grafana provisioning
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/provisioning/datasources
mkdir -p dashboards

# Grafana data source
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

# Download a sample Grafana dashboard
wget -O dashboards/node_exporter_full.json https://grafana.com/api/dashboards/1860/revisions/33/download

# Docker Compose configuration
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

  alertmanager:
    image: prom/alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    command:
      - "--config.file=/etc/alertmanager/alertmanager.yml"

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
