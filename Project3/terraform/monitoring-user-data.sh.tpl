#!/bin/bash

sudo apt update -y
sudo apt install -y docker.io docker-compose unzip wget curl

sudo usermod -aG docker ubuntu

mkdir -p /opt/monitoring
cd /opt/monitoring

cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: "node_exporter_metrics"
    static_configs:
      - targets: ["${web_app_private_ip}:9100"]
EOF

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

mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/provisioning/datasources
mkdir -p dashboards

cat <<EOF > grafana/provisioning/datasources/datasource.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

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

wget -O dashboards/node_exporter_full.json https://grafana.com/api/dashboards/1860/revisions/33/download

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

docker compose up -d
