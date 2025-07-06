#!/bin/bash
sudo apt update -y
sudo apt install -y wget apt-transport-https gnupg

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update && sudo apt install -y filebeat

sudo filebeat modules enable system
sudo filebeat setup

sudo systemctl enable filebeat
sudo systemctl start filebeat
