provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = file("${path.module}/project3-key.pub")
}

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.this.id
  name   = "${var.project_name}-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App Port"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_security_group" "monitoring_sg" {
  vpc_id = aws_vpc.this.id
  name   = "${var.project_name}-monitoring-sg"

  ingress {
    description     = "SSH from Web App"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description     = "Prometheus"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description     = "Grafana"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-monitoring-sg"
  }
}

resource "aws_eip" "web_app_eip" {
  instance = aws_instance.web_app.id

  tags = {
    Name = "${var.project_name}-eip"
  }
}

resource "aws_instance" "web_app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y nodejs npm git curl

    sudo npm install -g pm2

    git clone https://github.com/Osi45/Devops-Journey-Practice.git /home/ubuntu/app || true
    cd /home/ubuntu/app/Project3/app && npm install && pm2 start index.js || echo "App not found"

    wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
    sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin
    rm -rf node_exporter-1.7.0.linux-amd64*

    sudo useradd -rs /bin/false nodeusr
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null << EOL
    [Unit]
    Description=Node Exporter
    After=network.target
    [Service]
    User=nodeusr
    ExecStart=/usr/local/bin/node_exporter
    [Install]
    WantedBy=default.target
    EOL

    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
  EOF

  tags = {
    Name = "${var.project_name}-web-app"
  }
}

resource "aws_instance" "monitoring" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y docker.io docker-compose git

    sudo systemctl enable docker
    sudo systemctl start docker

    mkdir -p /opt/monitoring
    cd /opt/monitoring

    cat << EOL > docker-compose.yml
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

    cat << EOL > prometheus.yml
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'node_exporter_metrics'
        static_configs:
          - targets: ['${aws_instance.web_app.private_ip}:9100']
    EOL

    sudo docker-compose up -d
  EOF

  tags = {
    Name = "${var.project_name}-monitoring"
  }
}

output "web_app_public_ip" {
  value = aws_instance.web_app.public_ip
}
