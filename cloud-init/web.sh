#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gpg awscli docker.io docker-compose-v2 nginx rsyslog ufw
cat > /etc/docker/daemon.json <<'DOCKER'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  },
  "live-restore": true
}
DOCKER
systemctl enable --now docker
systemctl restart docker
systemctl enable --now rsyslog
ufw logging low

curl --fail --show-error --silent https://amazon-efs-utils.aws.com/efs-utils-installer.sh | bash -s -- --install
mkdir -p /mnt/compartilhado
grep -qF "${efs_id}:/ /mnt/compartilhado efs _netdev,tls 0 0" /etc/fstab || \
  echo "${efs_id}:/ /mnt/compartilhado efs _netdev,tls 0 0" >> /etc/fstab
mount -a -t efs

curl --fail --show-error --silent https://packages.fluentbit.io/fluentbit.key | \
  gpg --dearmor --yes -o /usr/share/keyrings/fluentbit-keyring.gpg
codename=$(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release 2>/dev/null || lsb_release -cs)
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/$codename $codename main" \
  > /etc/apt/sources.list.d/fluent-bit.list
apt-get update
apt-get install -y fluent-bit

mkdir -p /var/lib/fluent-bit/storage /var/lib/fluent-bit/s3
printf '%s' '${fluent_bit_config_b64}' | base64 --decode > /etc/fluent-bit/fluent-bit.yaml
chmod 640 /etc/fluent-bit/fluent-bit.yaml
install -d -m 755 /etc/systemd/system/fluent-bit.service.d
cat > /etc/systemd/system/fluent-bit.service.d/config.conf <<'UNIT'
[Service]
ExecStart=
ExecStart=/opt/fluent-bit/bin/fluent-bit --config=/etc/fluent-bit/fluent-bit.yaml
User=root
UNIT
systemctl daemon-reload
systemctl enable fluent-bit
systemctl restart fluent-bit

cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    location /api/ {
        proxy_pass http://${backend_private_ip}:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX
nginx -t
systemctl enable --now nginx
systemctl reload nginx

install -d -m 750 /opt/infra-pilates/frontend
printf '%s' '${frontend_compose_b64}' | base64 --decode > /opt/infra-pilates/frontend/compose.yml
printf '%s' '${deploy_frontend_script_b64}' | base64 --decode > /usr/local/bin/deploy-frontend
chmod 750 /usr/local/bin/deploy-frontend
