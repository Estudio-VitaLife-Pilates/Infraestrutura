#!/bin/bash
set -euo pipefail

# Terraform fills in the AWS values before this script is installed on the host.
image_tag="$${1:?Usage: deploy-backend IMAGE_TAG}"
if [[ ! "$image_tag" =~ ^[A-Za-z0-9_.-]{1,128}$ ]]; then
  echo "Invalid ECR image tag" >&2
  exit 2
fi

region="${aws_region}"
registry="${ecr_registry}"
image="$registry/backend/dev:$image_tag"
compose_dir=/opt/infra-pilates/backend

if [ "$(docker inspect --format '{{.State.Running}}' pilates-backend 2>/dev/null || true)" = "true" ] && \
   [ "$(docker inspect --format '{{.Config.Image}}' pilates-backend)" = "$image" ]; then
  exit 0
fi

aws ecr get-login-password --region "$region" | \
  docker login --username AWS --password-stdin "$registry"

printf 'BACKEND_IMAGE=%s/backend/dev:%s\n' "$registry" "$image_tag" > "$compose_dir/.env"
chmod 600 "$compose_dir/.env"
docker compose --project-name pilates-backend --project-directory "$compose_dir" \
  -f "$compose_dir/compose.yml" pull
docker compose --project-name pilates-backend --project-directory "$compose_dir" \
  -f "$compose_dir/compose.yml" up -d --remove-orphans
printf '%s\n' "$image_tag" > "$compose_dir/image-tag"
chmod 600 "$compose_dir/image-tag"
