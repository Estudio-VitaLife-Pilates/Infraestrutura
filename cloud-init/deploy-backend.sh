#!/bin/bash
set -euo pipefail

# Terraform fills in the AWS values before this script is installed on the host.
image_tag="$${1:?Usage: deploy-backend IMAGE_TAG [DATABASE_HOST]}"
if [[ ! "$image_tag" =~ ^[A-Za-z0-9_.-]{1,128}$ ]]; then
  echo "Invalid ECR image tag" >&2
  exit 2
fi

compose_dir=/opt/infra-pilates/backend
database_host="$${2:-}"
if [ -z "$database_host" ]; then
  database_host=$(sed -n 's/^DATABASE_HOST=//p' "$compose_dir/.env" 2>/dev/null | tail -n 1)
fi
if [[ ! "$database_host" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "A valid database IPv4 address is required" >&2
  exit 2
fi
IFS=. read -r -a database_octets <<< "$database_host"
for octet in "$${database_octets[@]}"; do
  if (( octet > 255 )); then
    echo "Invalid database IPv4 address" >&2
    exit 2
  fi
done

region="${aws_region}"
registry="${ecr_registry}"
image="$registry/backend/dev:$image_tag"
database_url="jdbc:mysql://$database_host:3306/pilates"

if [ "$(docker inspect --format '{{.State.Running}}' pilates-backend 2>/dev/null || true)" = "true" ] && \
   [ "$(docker inspect --format '{{.Config.Image}}' pilates-backend)" = "$image" ] && \
   [ "$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' pilates-backend | sed -n 's/^DB_URL=//p')" = "$database_url" ]; then
  exit 0
fi

aws ecr get-login-password --region "$region" | \
  docker login --username AWS --password-stdin "$registry"

printf 'BACKEND_IMAGE=%s/backend/dev:%s\nDATABASE_HOST=%s\n' "$registry" "$image_tag" "$database_host" > "$compose_dir/.env"
chmod 600 "$compose_dir/.env"
docker compose --project-name pilates-backend --project-directory "$compose_dir" \
  -f "$compose_dir/compose.yml" pull
docker compose --project-name pilates-backend --project-directory "$compose_dir" \
  -f "$compose_dir/compose.yml" up -d --remove-orphans
printf '%s\n' "$image_tag" > "$compose_dir/image-tag"
chmod 600 "$compose_dir/image-tag"
