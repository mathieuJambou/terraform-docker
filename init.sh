#!/bin/bash
sudo apt update

# Install packages to allow apt to use a repository over HTTPS:
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Add Dockerâ€™s official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# install docker
sudo apt update
sudo apt install -y docker docker-compose

sudo groupadd docker
sudo usermod -aG docker azureuser

