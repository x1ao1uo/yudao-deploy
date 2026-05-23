#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/ensure-ssh-tunnel.sh"
"$SCRIPT_DIR/check-local-prereqs.sh"

cd "$DEPLOY_DIR"
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml up -d --build
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
