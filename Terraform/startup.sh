#!/bin/bash
apt-get -y update 

#Installing Docker
apt-get -y install ca-certificates curl gnupg unzip
mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
"deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

#Installing AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

MONGO_URL=$(aws ssm get-parameter --name "/social-app/mongodb_url" --with-decryption --query "Parameter.Value" --output text)
#TIMESTAMP=$(date +%Y%m%d%H%M%S)

CURRENT_DIR=$(pwd)

cat > "${CURRENT_DIR}/docker-compose.yml" <<EOL
version: '3.8'
services:
  client:
    image: amberasif321/frontend:latest
    container_name: client
    networks:
      - socialapp-network
    restart: always

  api:
    image: amberasif321/backend:latest
    container_name: server
    environment:
      - PORT=5000
      - MONGO_URL=${MONGO_URL}
      - JWT_SECRET=secret
    networks:
      - socialapp-network
    restart: always

  nginx:
    image: amberasif321/loadbalancer:latest
    container_name: nginx
    ports:
      - "80:80"
    networks:
      - socialapp-network
    restart: always
    depends_on:
      - client
      - server

networks:
  socialapp-network:
EOL


cd "${CURRENT_DIR}"

#Always pull the latest image
docker compose -p "social-app" pull
docker compose -p "social-app" up -d


