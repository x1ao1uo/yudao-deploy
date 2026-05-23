#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$DEPLOY_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/ruoyi-vue-pro"
M2_DIR="${M2_DIR:-$HOME/.m2}"
MAVEN_IMAGE="${MAVEN_IMAGE:-maven:3.9.9-eclipse-temurin-8}"

if [[ ! -f "$BACKEND_DIR/pom.xml" ]]; then
  echo "找不到后端 pom.xml: $BACKEND_DIR/pom.xml" >&2
  exit 1
fi

mkdir -p "$M2_DIR"

docker run --rm \
  -v "$BACKEND_DIR:/workspace" \
  -v "$M2_DIR:/root/.m2" \
  -w /workspace \
  "$MAVEN_IMAGE" \
  mvn -pl yudao-server -am -DskipTests package

JAR_FILE="$BACKEND_DIR/yudao-server/target/yudao-server.jar"
if [[ ! -f "$JAR_FILE" ]]; then
  echo "构建命令结束，但未找到 jar: $JAR_FILE" >&2
  exit 1
fi

echo "后端 jar 已生成: $JAR_FILE"
