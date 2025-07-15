Project 3:This a  full Stack Monitoring Setup i designed and implemented with Secure Access via AWS SSM

Project Overview:

This project provisions a complete DevOps monitoring pipeline in AWS:

- A **Node.js web application** deployed on an EC2 instance.
- A separate **monitoring stack** (Prometheus, Grafana, Elasticsearch, Kibana) on another EC2 instance using Docker Compose.
- The web app instance includes **Node Exporter** and **Filebeat** for metrics and log collection.
- Infrastructure is provisioned using **Terraform**, and all access is done securely via **AWS SSM Session Manager** (no public SSH or key pairs used).

Architecture

[My IP: 65.92.152.43]
       |
       |  🔐 SSM Port Forwarding
       ↓
[Web EC2 Instance]
    - Node.js App
    - Node Exporter (9100)
    - Filebeat (→ Elasticsearch)

       |
       ↓
[Monitoring EC2 Instance]
    - Prometheus (9090)
    - Grafana (3000)
    - Elasticsearch (9200)
    - Kibana (5601)
```

🛠️ Tools Used

| Category              | Tool/Service                      | Purpose                                           |
|-----------------------|-----------------------------------|---------------------------------------------------|
| IaC                   | Terraform                         | Infrastructure provisioning                       |
| Compute               | EC2 (Ubuntu)                      | Hosts for app and monitoring                      |
| Containerization      | Docker, Docker Compose            | Runs monitoring stack                             |
| Monitoring            | Prometheus, Grafana               | Metrics collection and visualization              |
| Logs                  | Filebeat, Elasticsearch, Kibana   | Log shipping and analysis                         |
| Metrics Agent         | Node Exporter                     | System metrics on web instance                    |
| Secure Access         | AWS SSM Session Manager           | Bastionless, encrypted instance access            |
| OS                    | Ubuntu 24.04 LTS                  | Base EC2 AMI                                      |
| Networking            | VPC, Subnets, Security Groups     | Isolated and secure AWS environment               |


📁 Project Structure

project3/
├── ec2.tf
├── vpc.tf
├── security_groups.tf
├── outputs.tf
├── variables.tf
├── terraform.tfvars
├── monitoring-user-data.sh.tpl
├── web-user-data.sh.tpl
└── README.md  <-- (this file)
```

---

🔐Security Group Summary

Web App (`web_sg`)
- `80` (HTTP) → 0.0.0.0/0
- `4000` (Node.js dev port) → 65.92.152.43/32
- `9100` (node_exporter) ← from monitoring SG

Monitoring (`monitoring_sg`)
- `9090`, `3000`, `5601`, `9200` → 65.92.152.43/32
- Egress → 0.0.0.0/0

Cross-SG Rule

hcl
resource "aws_security_group_rule" "allow_node_exporter_scrape" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.monitoring_sg.id
  description              = "Allow Prometheus to scrape Node Exporter metrics"
}
```

---

 Deploy Infrastructure

```bash
terraform init
terraform plan -out=tfplan
terraform apply "tfplan"


️EC2 Configuration via User Data

Web EC2 (`web-user-data.sh.tpl`)
- Installs:
  - Node.js app
  - PM2 process manager
  - Node Exporter
  - Filebeat (configured to send logs to Elasticsearch in monitoring EC2)

Monitoring EC2 (`monitoring-user-data.sh.tpl`)
- Installs Docker & Docker Compose
- Creates:
  - `prometheus.yml` (scraping metrics from web EC2)
  - `docker-compose.yml` with:
    - Prometheus
    - Grafana
    - Elasticsearch
    - Kibana
- Starts all services with `docker-compose up -d`


Monitoring Stack Services

| Service        | Port | Notes                                     |
|----------------|------|-------------------------------------------|
| Prometheus     | 9090 | Metrics collection                        |
| Grafana        | 3000 | Dashboards and visualization              |
| Elasticsearch  | 9200 | Stores logs from Filebeat                 |
| Kibana         | 5601 | Log analysis and search interface         |

---

🔐 SSM Port Forwarding Access

   Example: Access Prometheus

```bash
aws ssm start-session \
  --target <monitoring-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9090"],"localPortNumber":["9090"]}'


Then in your browser:
- http://localhost:9090 → Prometheus
- http://localhost:3000 → Grafana
- http://localhost:9200 → Elasticsearch
- http://localhost:5601 → Kibana


✅ Verification Steps

Web EC2:

```bash
curl http://localhost:9100/metrics     # node_exporter metrics
sudo systemctl status filebeat         # confirm Filebeat is running


Monitoring EC2:

```bash
cd /opt/monitoring
sudo docker-compose ps                 # verify containers are UP


Local Machine:

- Use SSM to port-forward monitoring ports.
- Open respective services in browser via `localhost`.

---

This is what i intend to include in my future Improvements

- Add Prometheus alert rules (email, Slack)
- Secure access using NGINX reverse proxy with HTTPS
- Use Amazon OpenSearch instead of self-hosted ELK
- Replace EC2s with ECS or Fargate for scalability

---

👏 Conclusion

This project demonstrates a complete, secure, and production-ready observability setup using AWS-native and open-source tooling—all automated with Terraform and accessed without public IPs using AWS SSM.
