#!/bin/bash

# Update and install required packages
sudo apt update -y
sudo apt install -y docker.io unzip wget curl  

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

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
      - targets: ["${web_app_private_ip}:9100"]
EOF

# Alerting rules
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

# Alertmanager config
cat <<EOF > alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_wait: 10s
  group_interval: 30s
  repeat_interval: 1h
  receiver: 'pagerduty-notifications'

receivers:
  - name: 'pagerduty-notifications'
    pagerduty_configs:
      - routing_key: "${PAGERDUTY_ROUTING_KEY}"
        send_resolved: true

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

# Download sample dashboard
wget -O dashboards/node_exporter_full.json https://grafana.com/api/dashboards/1860/revisions/33/download

# Docker Compose file
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts.yml:/etc/prometheus/alerts.yml
    ports:
      - "9090:9090"
    networks:
      - monitoring_net

  alertmanager:
    image: prom/alertmanager
    container_name: alertmanager
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    ports:
      - "9093:9093"
    environment:
      PAGER_INTEGRATION_KEY="${PAGER_INTEGRATION_KEY}"
    networks:
      - monitoring_net

  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./dashboards:/var/lib/grafana/dashboards
    networks:
      - monitoring_net

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.14.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    networks:
      - monitoring_net

  kibana:
    image: docker.elastic.co/kibana/kibana:8.13.2
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - monitoring_net

networks:
  monitoring_net:
    driver: bridge
EOF

# Launch the stack
docker-compose up -d
