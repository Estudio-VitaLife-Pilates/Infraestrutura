#!/bin/bash
set -euo pipefail

image_tag="$${1:?Usage: deploy-frontend IMAGE_TAG}"
if [[ ! "$image_tag" =~ ^[A-Za-z0-9_.-]{1,128}$ ]]; then
  echo "Invalid ECR image tag" >&2
  exit 2
fi

region="${aws_region}"
registry="${ecr_registry}"
image="$registry/frontend/dev:$image_tag"
compose_dir=/opt/infra-pilates/frontend

aws ecr get-login-password --region "$region" | \
  docker login --username AWS --password-stdin "$registry"

printf 'FRONTEND_IMAGE=%s\n' "$image" > "$compose_dir/.env"
chmod 600 "$compose_dir/.env"
docker compose --project-name pilates-frontend --project-directory "$compose_dir" \
  -f "$compose_dir/compose.yml" pull
docker compose --project-name pilates-frontend --project-directory "$compose_dir" \
  -f "$compose_dir/compose.yml" up -d --remove-orphans
printf '%s\n' "$image_tag" > "$compose_dir/image-tag"
chmod 600 "$compose_dir/image-tag"
