#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$DEPLOY_DIR/.." && pwd)"

ENV_FILE="$DEPLOY_DIR/.env.local-tunnel"
JAR_FILE="$ROOT_DIR/ruoyi-vue-pro/yudao-server/target/yudao-server.jar"
failures=0

echo "检查 Docker..."
docker --version
docker compose version

echo
echo "检查本地隧道端口..."
if nc -z 127.0.0.1 13306; then
  echo "MySQL 隧道可达: 127.0.0.1:13306"
else
  echo "MySQL 隧道不可达: 127.0.0.1:13306" >&2
  echo "请先运行: /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac/start-ssh-tunnel.sh" >&2
  failures=$((failures + 1))
fi

if nc -z 127.0.0.1 16379; then
  echo "Redis 隧道可达: 127.0.0.1:16379"
else
  echo "Redis 隧道不可达: 127.0.0.1:16379" >&2
  echo "请先运行: /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac/start-ssh-tunnel.sh" >&2
  failures=$((failures + 1))
fi

echo
echo "检查环境变量文件..."
if [[ -f "$ENV_FILE" ]]; then
  echo "已找到: $ENV_FILE"
else
  echo "缺少: $ENV_FILE" >&2
  echo "请执行: cp .env.local-tunnel.example .env.local-tunnel" >&2
  echo "然后填入真实 MySQL/Redis 信息。" >&2
  failures=$((failures + 1))
fi

echo
echo "检查后端 jar..."
if [[ -f "$JAR_FILE" ]]; then
  echo "已找到: $JAR_FILE"
else
  echo "缺少: $JAR_FILE" >&2
  echo "请执行: ./scripts/build-backend-jar-with-docker.sh" >&2
  failures=$((failures + 1))
fi

echo
echo "检查 Docker Compose 配置..."
cd "$DEPLOY_DIR"
if [[ -f "$ENV_FILE" ]]; then
  docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml config >/dev/null
  echo "Docker Compose 配置可展开。"
else
  echo "跳过 Docker Compose 配置检查，因为缺少 .env.local-tunnel。" >&2
fi

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "前置检查未通过，缺项数量: $failures" >&2
  exit 1
fi

echo
echo "前置检查通过。"
