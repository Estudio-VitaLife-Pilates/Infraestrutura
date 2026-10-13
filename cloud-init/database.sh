#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gpg docker.io docker-compose-v2 rsyslog ufw
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

volume_serial="${volume_serial}"
volume_device=""
for attempt in $(seq 1 60); do
  volume_device=$(lsblk --nodeps --noheadings --output NAME,SERIAL | \
    awk -v serial="$volume_serial" '$2 == serial { print "/dev/" $1; exit }')
  if [ -n "$volume_device" ]; then
    break
  fi
  sleep 2
done
if [ -z "$volume_device" ]; then
  echo "The persistent MySQL EBS volume was not found." >&2
  exit 1
fi

if ! blkid "$volume_device" >/dev/null 2>&1; then
  mkfs.ext4 "$volume_device"
fi
mysql_uuid=$(blkid --output value --match-tag UUID "$volume_device")
mkdir -p /mnt/pilates-mysql
grep -qF "UUID=$mysql_uuid /mnt/pilates-mysql " /etc/fstab || \
  echo "UUID=$mysql_uuid /mnt/pilates-mysql ext4 defaults,nofail,x-systemd.device-timeout=60 0 2" >> /etc/fstab
mount -a
chown 999:999 /mnt/pilates-mysql

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

install -d -m 750 /opt/infra-pilates/database
printf '%s' '${database_compose_b64}' | base64 --decode > /opt/infra-pilates/database/compose.yml

cat > /usr/local/bin/start-pilates-mysql <<'SCRIPT'
#!/bin/bash
set -euo pipefail

if [ "$(docker inspect --format '{{.State.Running}}' pilates-mysql 2>/dev/null || true)" = "true" ]; then
  exit 0
fi

compose_dir=/opt/infra-pilates/database
cat > "$compose_dir/.env" <<'ENV'
MYSQL_DATA_DIR=/mnt/pilates-mysql
ENV
chmod 600 "$compose_dir/.env"

docker compose --project-name pilates-database --project-directory "$compose_dir" \
  -f "$compose_dir/compose.yml" up -d
SCRIPT
chmod 750 /usr/local/bin/start-pilates-mysql

cat > /etc/systemd/system/pilates-mysql.service <<'UNIT'
[Unit]
Description=Run the Pilates MySQL container
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target
RequiresMountsFor=/mnt/pilates-mysql

[Service]
Type=oneshot
ExecStart=/usr/local/bin/start-pilates-mysql
UNIT

cat > /etc/systemd/system/pilates-mysql.timer <<'TIMER'
[Unit]
Description=Retry starting the Pilates MySQL container

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=pilates-mysql.service

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now pilates-mysql.timer
