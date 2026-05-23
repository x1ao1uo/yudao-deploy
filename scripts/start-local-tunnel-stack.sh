#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/ensure-ssh-tunnel.sh"
"$SCRIPT_DIR/check-local-prereqs.sh"

cd "$DEPLOY_DIR"
COMPOSE_PULL_POLICY="${COMPOSE_PULL_POLICY:-never}"
YUDAO_BUILD_IMAGES="${YUDAO_BUILD_IMAGES:-auto}"
COMPOSE_ARGS=(--env-file .env.local-tunnel -f docker-compose.local-tunnel.yml)

env_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' .env.local-tunnel
}

SERVER_IMAGE="$(env_value SERVER_IMAGE)"
FRONTEND_IMAGE="$(env_value FRONTEND_IMAGE)"
SERVER_IMAGE="${SERVER_IMAGE:-yudao-server:local-tunnel}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-yudao-admin:local-tunnel}"

has_local_images() {
  docker image inspect "$SERVER_IMAGE" "$FRONTEND_IMAGE" >/dev/null 2>&1
}

case "$YUDAO_BUILD_IMAGES" in
  auto)
    if has_local_images; then
      echo "已找到本地镜像，直接启动: $SERVER_IMAGE, $FRONTEND_IMAGE"
      docker compose "${COMPOSE_ARGS[@]}" up -d --no-build
    else
      echo "本地镜像不存在，开始构建: $SERVER_IMAGE, $FRONTEND_IMAGE"
      docker compose "${COMPOSE_ARGS[@]}" up -d --build --pull "$COMPOSE_PULL_POLICY"
    fi
    ;;
  0|false|False|no|No)
    docker compose "${COMPOSE_ARGS[@]}" up -d --no-build
    ;;
  1|true|True|yes|Yes)
    docker compose "${COMPOSE_ARGS[@]}" up -d --build --pull "$COMPOSE_PULL_POLICY"
    ;;
  *)
    echo "YUDAO_BUILD_IMAGES 只能是 auto、true 或 false，当前值: $YUDAO_BUILD_IMAGES" >&2
    exit 1
    ;;
esac

docker compose "${COMPOSE_ARGS[@]}" ps
