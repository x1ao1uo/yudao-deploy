# yudao-deploy

这个目录是当前环境专用的 Docker 部署适配层，不修改 `ruoyi-vue-pro` 和 `yudao-ui-admin-vue3` 两个上游仓库。

## 部署边界

- 只部署后端 `yudao-server` 和前端 `yudao-ui-admin-vue3`。
- 不启动 MySQL 容器。
- 不启动 Redis 容器。
- 本地开发必须通过 `/Volumes/LVLIAN_1T/code/ssh-tunnel-config` 访问服务器 MySQL/Redis。
- 服务器正式部署不使用 SSH 隧道，但后端容器仍然要用宿主机可达地址访问服务器本机 MySQL/Redis。

## BPM 启用要求

BPM 不是单独的 Docker 容器，也不是需要额外启动的独立服务。当前单体后端里，BPM 跟随 `yudao-server` 一起启动。

重新克隆或更新 `ruoyi-vue-pro` 后，启动 BPM 前必须确认下面两个文件已经打开 BPM 模块：

1. `/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/pom.xml`

```xml
<module>yudao-module-bpm</module>
```

2. `/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/pom.xml`

```xml
<dependency>
    <groupId>cn.iocoder.boot</groupId>
    <artifactId>yudao-module-bpm</artifactId>
    <version>${revision}</version>
</dependency>
```

检查命令：

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
git diff -- pom.xml yudao-server/pom.xml
```

期望只看到 BPM module 和 `yudao-module-bpm` dependency 这两处启用改动。不要为了启用 BPM 顺手修改 Flowable 版本、JDK 版本或部署镜像，除非明确决定做 Flowable/JDK 迁移。

当前远程数据库里 Flowable schema 是 `7.2.0.2`，而当前开源后端默认 Flowable 是 `6.8.1`。如果按上面的最小改动启用 BPM 并直接连接这套已有数据库，后端会在 Flowable 初始化阶段失败：

```text
Could not update Flowable database schema: unknown version from database: '7.2.0.2'
```

这个错误说明数据库里的 Flowable 版本比当前开源代码新，不是 Docker 端口、SSH 隧道、MySQL 密码或 Redis 连接问题。

## 本地需要启动哪些

本地 Docker 开发部署只需要启动：

1. SSH 隧道：让本机访问服务器已有 MySQL/Redis。
2. `server`：后端 `yudao-server` 容器，BPM 跟随它一起启动。
3. `frontend`：前端 Nginx 容器，提供页面并反代 `/admin-api` 到 `server:48080`。

本地不启动：

- MySQL 容器。
- Redis 容器。
- 单独的 BPM 容器。

## 本地开发

### 1. 启动隧道

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/ensure-ssh-tunnel.sh
```

这个脚本会使用 `/Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac/ssh_config`，通过 OpenSSH 的 `-fN` 后台模式启动隧道。

如果要手动前台启动，也可以运行：

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./start-ssh-tunnel.sh
```

### 2. 测试隧道

另开一个终端：

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./test-ssh-tunnel.sh
```

本地 Docker 容器使用：

```text
MySQL: host.docker.internal:13306
Redis: host.docker.internal:16379
```

### 3. 准备本地环境变量

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
cp .env.local-tunnel.example .env.local-tunnel
```

编辑 `.env.local-tunnel`，填入服务器真实 MySQL/Redis 账号密码。

当前这个 `yudao-deploy` 是私有部署仓库，按当前约定会提交 `.env.local-tunnel` 和 `.env.server`，方便本机与服务器复用同一套部署配置。如果以后要公开这个仓库，必须先删除真实密码并改回只提交 `.env.*.example`。

需要提供哪些值见：

```text
NEED-INFO.md
```

### 4. 构建后端 jar

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
mvn -pl yudao-server -am -DskipTests package
```

如果本机没有 Maven，可以在部署目录执行 Docker 版构建：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/build-backend-jar-with-docker.sh
```

确认存在：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/target/yudao-server.jar
```

前端 Dockerfile 已固定使用 `pnpm 9.15.9`，因为当前前端锁文件是 `lockfileVersion: '9.0'`。不要让 Docker 构建直接使用 Corepack 拉取最新 pnpm 大版本，否则可能触发依赖构建脚本拦截策略导致安装失败。

前端 Dockerfile 也固定了：

```text
NODE_OPTIONS=--max-old-space-size=2048
```

原因是当前前端 Vite 构建在 Docker Desktop 里可能被系统杀掉并报 `cannot allocate memory`。限制 Node 堆内存可以避免构建进程把 Docker 可用内存打满。

### 5. 启动本地 Docker

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/start-local-tunnel-stack.sh
```

也可以直接使用 compose 启动已有镜像：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml up -d --no-build
```

`start-local-tunnel-stack.sh` 会先自动确保 SSH 隧道可用，再检查 `.env.local-tunnel`、后端 jar 和 Docker Compose 配置。

脚本默认使用 `YUDAO_BUILD_IMAGES=auto`：

- 如果本地已经有 `SERVER_IMAGE` 和 `FRONTEND_IMAGE`，直接 `--no-build` 启动。
- 如果本地缺少镜像，才执行 `--build`。

如果代码或 jar 变了，需要强制重建镜像，先确保 Docker Hub 可访问，再运行：

```bash
YUDAO_BUILD_IMAGES=true COMPOSE_PULL_POLICY=missing ./scripts/start-local-tunnel-stack.sh
```

如果只想启动已有镜像，不允许构建：

```bash
YUDAO_BUILD_IMAGES=false ./scripts/start-local-tunnel-stack.sh
```

访问：

```text
前端: http://127.0.0.1:8080
后端: http://127.0.0.1:48080
```

查看状态和日志：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 server
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 frontend
```

如果 `server` 反复重启，并且日志包含：

```text
Could not update Flowable database schema: unknown version from database: '7.2.0.2'
```

说明 Docker、SSH 隧道、MySQL 和 Redis 都已经走通，真正阻塞点是当前开源后端默认 Flowable `6.8.1` 无法使用服务器已有数据库里的 Flowable `7.2.0.2` schema。

停止：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml down
```

## 本地前置检查

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/check-local-prereqs.sh
```

这个脚本会检查：

- Docker 是否可用。
- SSH 隧道的 `127.0.0.1:13306` 和 `127.0.0.1:16379` 是否可达。
- `.env.local-tunnel` 是否存在。
- 后端 `yudao-server.jar` 是否存在。
- Docker Compose 配置是否能展开。

## 服务器部署

### 1. 准备服务器环境变量

```bash
cd /path/to/yudao-deploy
cp .env.server.example .env.server
```

编辑 `.env.server`，填入服务器真实 MySQL/Redis 账号密码。

你的服务器部署形态是：

```text
后端 yudao-server: Docker 容器
MySQL: 服务器宿主机 3306
Redis: 服务器宿主机 6379
```

所以 `.env.server` 里不要把数据库地址改成 `127.0.0.1:3306`。在后端容器内部，`127.0.0.1` 指的是容器自己，不是服务器宿主机。默认使用：

```text
MySQL: host.docker.internal:3306
Redis: host.docker.internal:6379
```

只有后端不是 Docker 容器、而是直接跑在服务器宿主机进程里时，才使用 `127.0.0.1:3306` 和 `127.0.0.1:6379`。

默认前端容器只绑定：

```text
127.0.0.1:18080
```

服务器已有 Nginx 反代到：

```text
http://127.0.0.1:18080
```

不要把 MySQL `3306` 或 Redis `6379` 开到公网。

### 2. 构建后端 jar

```bash
cd /path/to/ruoyi-vue-pro
mvn -pl yudao-server -am -DskipTests package
```

### 3. 启动服务器 Docker

```bash
cd /path/to/yudao-deploy
docker compose --env-file .env.server -f docker-compose.server.yml up -d --build --pull missing
```

查看状态：

```bash
docker compose --env-file .env.server -f docker-compose.server.yml ps
docker compose --env-file .env.server -f docker-compose.server.yml logs --tail=120 server
```

## 当前验证结论

2026-05-24 已按本文档跑过本地隧道部署流程：

- 前置检查通过：Docker、SSH 隧道、`.env.local-tunnel`、后端 jar、Compose 配置都可用。
- `start-local-tunnel-stack.sh` 可以使用已有本地镜像启动 `frontend` 和 `server`。
- 前端 `http://127.0.0.1:8080` 返回 `200 OK`。
- 后端启动时已经连上 MySQL 和 Redis，但 Flowable 初始化失败，`server` 会反复重启。

当前还不能称为完整可用部署。阻塞点不是 Docker、Nginx、SSH 隧道、MySQL 密码或 Redis，而是服务器现有数据库 Flowable schema `7.2.0.2` 与当前开源后端默认 Flowable `6.8.1` 不兼容。

## 重要说明

后端如果跑在 Docker 容器里，`127.0.0.1:3306` 指的是容器自己，不是服务器宿主机。当前配置用 `host.docker.internal` 访问宿主机 MySQL/Redis；`docker-compose.server.yml` 里也加了 `host.docker.internal:host-gateway`，兼容 Linux Docker。
