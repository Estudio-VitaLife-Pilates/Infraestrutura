#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gpg awscli docker.io docker-compose-v2 rsyslog ufw
systemctl enable --now docker
systemctl enable --now rsyslog
ufw logging low

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
systemctl restart docker

curl --fail --show-error --silent https://packages.fluentbit.io/fluentbit.key | \
  gpg --dearmor --yes -o /usr/share/keyrings/fluentbit-keyring.gpg
codename=$(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release 2>/dev/null || lsb_release -cs)
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/$codename $codename main" \
  > /etc/apt/sources.list.d/fluent-bit.list
apt-get update
apt-get install -y fluent-bit
usermod -aG adm fluent-bit
if getent group systemd-journal >/dev/null; then
  usermod -aG systemd-journal fluent-bit
fi
mkdir -p /var/lib/fluent-bit/storage /var/lib/fluent-bit/s3
printf '%s' '${fluent_bit_config_b64}' | base64 --decode > /etc/fluent-bit/fluent-bit.yaml
chmod 640 /etc/fluent-bit/fluent-bit.yaml
install -d -m 755 /etc/systemd/system/fluent-bit.service.d
cat > /etc/systemd/system/fluent-bit.service.d/config.conf <<'UNIT'
[Service]
ExecStart=
ExecStart=/opt/fluent-bit/bin/fluent-bit --config=/etc/fluent-bit/fluent-bit.yaml
UNIT
systemctl daemon-reload
systemctl enable fluent-bit
systemctl restart fluent-bit

install -d -m 750 /opt/infra-pilates/backend
printf '%s' '${backend_compose_b64}' | base64 --decode > /opt/infra-pilates/backend/compose.yml
printf '%s' '${deploy_script_b64}' | base64 --decode > /usr/local/bin/deploy-backend
chmod 750 /usr/local/bin/deploy-backend

cat > /etc/systemd/system/pilates-backend.service <<'UNIT'
[Unit]
Description=Run the latest Pilates backend image from ECR
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'test -s /opt/infra-pilates/backend/image-tag && exec /usr/local/bin/deploy-backend "$$(cat /opt/infra-pilates/backend/image-tag)"'
UNIT

cat > /etc/systemd/system/pilates-backend.timer <<'TIMER'
[Unit]
Description=Retry starting the Pilates backend container

[Timer]
OnBootSec=90s
OnUnitInactiveSec=5min
Unit=pilates-backend.service

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now pilates-backend.timer
