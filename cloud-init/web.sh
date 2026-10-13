#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gpg nginx rsyslog ufw
systemctl enable --now nginx
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
