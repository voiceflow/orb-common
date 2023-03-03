#!/bin/bash

sudo apt update
sudo apt install -y cpio
sudo apt install -y python3-pip nginx make g++ postgresql-client wget libnss3-tools apt-transport-https ca-certificates curl gnupg-agent software-properties-common
export DOCKERIZE_VERSION="v0.6.1"
wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz
sudo tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz
rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

export MKCERT_VERSION="v1.4.0"
wget https://github.com/FiloSottile/mkcert/releases/download/$MKCERT_VERSION/mkcert-$MKCERT_VERSION-linux-amd64
chmod +x mkcert-$MKCERT_VERSION-linux-amd64
sudo mv mkcert-$MKCERT_VERSION-linux-amd64 /usr/local/bin/mkcert
sudo mkcert -install

curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt-get update
sudo apt update
sudo apt-get -y install redis-tools

# AWS CLI and login
sudo pip3 install awscli --ignore-installed six
touch /tmp/executor_finished.txt