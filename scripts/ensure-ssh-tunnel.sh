#!/usr/bin/env bash
set -euo pipefail

TUNNEL_DIR="/Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac"
SSH_CONFIG="$TUNNEL_DIR/ssh_config"

mysql_ok=false
redis_ok=false

if nc -z 127.0.0.1 13306 >/dev/null 2>&1; then
  mysql_ok=true
fi

if nc -z 127.0.0.1 16379 >/dev/null 2>&1; then
  redis_ok=true
fi

if [[ "$mysql_ok" == true && "$redis_ok" == true ]]; then
  echo "SSH 隧道已可用: 127.0.0.1:13306, 127.0.0.1:16379"
  exit 0
fi

echo "启动 SSH 隧道后台进程..."
cd "$TUNNEL_DIR"
ssh -F "$SSH_CONFIG" -fN ssh-tunnel-win

sleep 2

if nc -z 127.0.0.1 13306 >/dev/null 2>&1 && nc -z 127.0.0.1 16379 >/dev/null 2>&1; then
  echo "SSH 隧道启动成功: 127.0.0.1:13306, 127.0.0.1:16379"
else
  echo "SSH 隧道启动失败或端口不可达。" >&2
  echo "请检查: $TUNNEL_DIR/ssh_config" >&2
  exit 1
fi
