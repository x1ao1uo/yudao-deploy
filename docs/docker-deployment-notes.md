# Docker 部署记录与执行方案

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` when turning this document into deploy files and running the deployment task-by-task.

**Goal:** 使用 Docker 容器部署当前目录下克隆的后端和前端项目，先在本机通过 SSH 隧道连接真实服务器上的 MySQL/Redis 做开发验证，后续再部署到同一台真实服务器。

**Architecture:** 后端使用 `ruoyi-vue-pro` 里的 Spring Boot `yudao-server`，监听 `48080`；前端使用独立克隆的 `yudao-ui-admin-vue3`，通过 pnpm 构建后交给 Nginx 提供静态页面，并由 Nginx 反代后端 API。数据库和 Redis 不在本地新建，开发阶段通过 SSH 隧道访问服务器已有服务，服务器正式部署阶段直接访问服务器本机已有服务。

**Tech Stack:** Docker Compose、Spring Boot 2.7、Java 8 runtime、Vue 3、Vite、pnpm、Nginx、MySQL、Redis、OpenSSH local forwarding。

---

## 用户意图记录

- 当前工作目录：`/Volumes/LVLIAN_1T/yudao`
- 后端仓库：`/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro`
- 前端仓库：`/Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3`
- SSH 隧道配置仓库：`/Volumes/LVLIAN_1T/code/ssh-tunnel-config`
- 目标：前端和后端都用 Docker 容器部署。
- 本地开发阶段：MySQL 和 Redis 都必须使用 `/Volumes/LVLIAN_1T/code/ssh-tunnel-config` 这套 SSH 隧道连接真实服务器上的数据。
- 本地开发阶段：不启动本地 MySQL 容器、不启动本地 Redis 容器、不连接本机已有 MySQL/Redis。
- 服务器正式部署阶段：部署到真实服务器 `120.236.17.146`，不再通过 SSH 隧道连接数据库和 Redis。
- 安全要求：不要把 MySQL `3306` 和 Redis `6379` 直接暴露到公网。当前 `yudao-deploy` 是私有部署仓库，按当前约定会提交 `.env.local-tunnel` 和 `.env.server`；如果以后改成公开仓库，必须先移除真实密码。

## 当前仓库事实

### 后端 `ruoyi-vue-pro`

- 项目自身已经带了 Docker 相关文件：
  - `ruoyi-vue-pro/yudao-server/Dockerfile`
  - `ruoyi-vue-pro/script/docker/docker-compose.yml`
  - `ruoyi-vue-pro/script/docker/docker.env`
- `yudao-server/Dockerfile` 是运行镜像，不负责 Maven 构建：
  - 基础镜像：`eclipse-temurin:8-jre`
  - 需要提前存在 `yudao-server/target/yudao-server.jar`
  - 容器内启动命令：`java ${JAVA_OPTS} -jar app.jar $ARGS`
  - 暴露端口：`48080`
- `script/docker/docker-compose.yml` 不是当前最合适的直接入口：
  - 它会额外启动 MySQL 和 Redis，但本需求是沿用服务器已有 MySQL/Redis。
  - 它的 `server.build.context` 指向 `./yudao-server/`，从 `script/docker` 目录看并不存在这个路径。
  - 它的 `admin.build.context` 指向 `./yudao-ui-admin`，不对应当前独立克隆的 `yudao-ui-admin-vue3`。
- 结论：后端有可复用的 Dockerfile 思路，但需要为当前两个独立仓库重写外层 compose 和构建上下文。

### 前端 `yudao-ui-admin-vue3`

- 独立前端仓库当前未看到可直接使用的 Dockerfile 或 Nginx 配置。
- `package.json` 要求：
  - Node：`>=20.19.0`
  - pnpm：`>=8.6.0`
  - 本地构建命令：`pnpm build:local`
  - 生产构建命令：`pnpm build:prod`
- `.env.local` 当前配置：
  - `VITE_BASE_URL='http://localhost:48080'`
  - `VITE_API_URL=/admin-api`
- `.env.prod` 当前配置：
  - `VITE_BASE_URL='http://localhost:48080'`
  - `VITE_API_URL=/admin-api`
  - `VITE_OUT_DIR=dist-prod`
- 结论：前端需要新建 Dockerfile 和 Nginx 配置。更推荐用 Nginx 同时提供静态文件和反代后端 API，避免浏览器直接跨域请求后端端口。

## SSH 隧道约定

隧道配置来源固定为：

```bash
/Volumes/LVLIAN_1T/code/ssh-tunnel-config
```

Mac 本地启动隧道：

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./start-ssh-tunnel.sh
```

Mac 本地测试隧道：

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./test-ssh-tunnel.sh
```

隧道映射：

```text
MySQL: 127.0.0.1:13306 -> 服务器 127.0.0.1:3306
Redis: 127.0.0.1:16379 -> 服务器 127.0.0.1:6379
SSH:   Administrator@120.236.17.146:2222
```

本机原生程序连接：

```text
MySQL: 127.0.0.1:13306
Redis: 127.0.0.1:16379
```

Docker Desktop 容器连接本机隧道时要使用：

```text
MySQL: host.docker.internal:13306
Redis: host.docker.internal:16379
```

本项目本地 Docker 开发必须使用上面这两个容器连接地址。不要在本地 compose 里新增 `mysql` 或 `redis` service，也不要把后端容器配置成连接 `127.0.0.1:3306` 或 `127.0.0.1:6379`。

## 关键网络规则

`127.0.0.1` 在不同位置含义不同：

| 运行位置 | `127.0.0.1` 指向 |
| --- | --- |
| Mac 终端 | Mac 本机 |
| Windows 终端 | Windows 本机 |
| Docker 容器内部 | 容器自己 |
| 服务器 PowerShell | 服务器本机 |

因此：

- 本地开发时，SSH 隧道监听在 Mac 的 `127.0.0.1:13306` 和 `127.0.0.1:16379`。
- 后端如果运行在 Mac 的 Docker 容器里，不能用 `127.0.0.1:13306` 访问隧道，应该用 `host.docker.internal:13306`。
- 服务器正式部署时，如果后端直接跑在服务器 PowerShell 或 WSL 主机里，连接 `127.0.0.1:3306` 是正确的。
- 服务器正式部署时，如果后端跑在 Docker 容器里，`127.0.0.1:3306` 默认不是服务器宿主机 MySQL，而是容器自身。
- 服务器 Docker 如果是 Windows Docker Desktop，后端容器连接宿主机 MySQL/Redis 通常使用 `host.docker.internal:3306` 和 `host.docker.internal:6379`。
- 服务器 Docker 如果是 Linux Docker，可以给 compose 加：

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

然后后端容器同样连接：

```text
MySQL: host.docker.internal:3306
Redis: host.docker.internal:6379
```

## 推荐部署目录

后续在当前工作目录创建独立部署目录，不直接污染两个上游项目：

```text
/Volumes/LVLIAN_1T/yudao/yudao-deploy/
├── docker-compose.local-tunnel.yml
├── docker-compose.server.yml
├── .env.local-tunnel.example
├── .env.server.example
├── backend/
│   └── Dockerfile
└── frontend/
    ├── Dockerfile
    └── nginx.conf
```

当前已经按这个结构创建部署目录。具体运行命令以 `yudao-deploy/README.md` 为准。

说明：

- `docker-compose.local-tunnel.yml`：本机开发使用，连接 SSH 隧道后的 `host.docker.internal:13306` 和 `host.docker.internal:16379`。
- `docker-compose.server.yml`：服务器正式部署使用，连接服务器本机已有 MySQL/Redis。
- `.env.*.example`：只放变量名和示例；当前私有仓库额外提交真实 `.env.local-tunnel` 和 `.env.server`，方便本机与服务器直接复用。
- `backend/Dockerfile`：可以选择继续沿用“先 Maven 打包，再复制 jar”的方式，也可以改成多阶段 Docker 构建。
- `frontend/Dockerfile`：Node/pnpm 构建前端，然后复制产物到 Nginx。
- `frontend/nginx.conf`：提供静态文件，并反代 `/admin-api`、WebSocket 和必要的后端路径到 `server:48080`。

前端 Dockerfile 固定 `pnpm 9.15.9` 和 `NODE_OPTIONS=--max-old-space-size=2048`。前者是为了匹配当前 `pnpm-lock.yaml` 的 `lockfileVersion: '9.0'`，后者是为了避免 Vite 构建在 Docker Desktop 中占用过多内存后被杀掉并报 `cannot allocate memory`。

## BPM 启用与启动服务

BPM 不需要单独启动一个 Docker 容器。当前部署使用 Spring Boot 单体后端，BPM 模块跟随 `yudao-server` 一起编译和启动。

重新克隆或更新后端仓库后，必须先确认两个文件已经打开 BPM：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/pom.xml
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/pom.xml
```

根 `pom.xml` 需要包含：

```xml
<module>yudao-module-bpm</module>
```

`yudao-server/pom.xml` 需要包含：

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

本地部署需要启动：

```text
SSH 隧道：连接服务器已有 MySQL/Redis
server：后端 yudao-server，BPM 跟随这个容器启动
frontend：前端 Nginx，提供静态页面并反代后端 API
```

本地部署不启动：

```text
MySQL 容器
Redis 容器
单独的 BPM 容器
```

服务器正式部署需要启动：

```text
server
frontend
服务器宿主机上已有的 MySQL
服务器宿主机上已有的 Redis
```

服务器正式部署不需要 SSH 隧道，也不要把 MySQL `3306` 或 Redis `6379` 开到公网。

当前实测结果：

```text
验证日期: 2026-05-24
前置检查: 通过
本地启动脚本: 可用，已有镜像时可直接 --no-build 启动
前端 http://127.0.0.1:8080: 200 OK
后端 MySQL/Redis 连接: 已进入初始化阶段，连接可达
当前远程数据库 Flowable schema: 7.2.0.2
当前开源后端默认 Flowable: 6.8.1
最小启用 BPM 后端启动结果: 失败
核心错误: Could not update Flowable database schema: unknown version from database: '7.2.0.2'
```

这说明当前已有服务器数据库不是这份开源后端默认 Flowable 版本初始化出来的。后续如果要让 BPM 在这套数据库上真正跑起来，只能在下面方案里选一个：

1. 使用和服务器数据库匹配的后端源码版本。
2. 给当前开源后端准备一套独立数据库，让 Flowable 6.8.1 自己初始化。
3. 明确做 Java 17 + Flowable 7 迁移；这属于框架兼容性迁移，不再是“只打开 BPM 模块”的最小改动。

## 本地开发部署流程

### 1. 启动 SSH 隧道

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./start-ssh-tunnel.sh
```

保持这个终端窗口运行。

### 2. 另开终端测试隧道

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./test-ssh-tunnel.sh
```

测试通过后，本机 Docker 容器才能通过 `host.docker.internal:13306` 和 `host.docker.internal:16379` 访问服务器数据。

本地开发容器的数据库和 Redis 地址固定为：

```text
MySQL: host.docker.internal:13306
Redis: host.docker.internal:16379
```

### 3. 构建后端 jar

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
mvn -pl yudao-server -am -DskipTests package
```

期望产物：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/target/yudao-server.jar
```

### 4. 使用本地隧道 compose 启动

后续创建部署文件后执行：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/start-local-tunnel-stack.sh
```

脚本默认使用 `YUDAO_BUILD_IMAGES=auto`。如果本地已经有 `SERVER_IMAGE` 和 `FRONTEND_IMAGE`，直接 `--no-build` 启动；如果本地缺少镜像，才执行 `--build`。代码或 jar 变更后需要强制重建镜像时，可以在确认 Docker Hub 可访问后临时运行：

```bash
YUDAO_BUILD_IMAGES=true COMPOSE_PULL_POLICY=missing ./scripts/start-local-tunnel-stack.sh
```

如果只想启动已有镜像，不允许构建：

```bash
YUDAO_BUILD_IMAGES=false ./scripts/start-local-tunnel-stack.sh
```

本地推荐访问：

```text
前端: http://127.0.0.1:8080
后端: http://127.0.0.1:48080
```

## 服务器正式部署流程

服务器正式部署不需要 SSH 隧道。目标是后端容器访问服务器本机已有 MySQL/Redis。

### Windows Docker Desktop 服务器

后端容器建议连接：

```text
MySQL: host.docker.internal:3306
Redis: host.docker.internal:6379
```

### Linux Docker 服务器

compose 给后端服务加：

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

后端容器连接：

```text
MySQL: host.docker.internal:3306
Redis: host.docker.internal:6379
```

### 只有非容器后端才直接用 `127.0.0.1`

如果后端不是 Docker 容器，而是直接运行在服务器宿主机上，才使用：

```text
MySQL: 127.0.0.1:3306
Redis: 127.0.0.1:6379
```

## 后端运行参数设计

后端容器使用 `SPRING_PROFILES_ACTIVE=local`，并通过 `ARGS` 覆盖数据库和 Redis 地址。

本地隧道环境示例：

```text
SPRING_PROFILES_ACTIVE=local
MASTER_DATASOURCE_URL=jdbc:mysql://host.docker.internal:13306/ruoyi-vue-pro?useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true&nullCatalogMeansCurrent=true
MASTER_DATASOURCE_USERNAME=<从服务器确认>
MASTER_DATASOURCE_PASSWORD=<私有部署仓库中可写真实值；公开前必须清理>
REDIS_HOST=host.docker.internal
REDIS_PORT=16379
REDIS_PASSWORD=<如服务器 Redis 无密码则留空>
```

服务器 Docker 环境示例：

```text
SPRING_PROFILES_ACTIVE=local
MASTER_DATASOURCE_URL=jdbc:mysql://host.docker.internal:3306/ruoyi-vue-pro?useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true&nullCatalogMeansCurrent=true
MASTER_DATASOURCE_USERNAME=<从服务器确认>
MASTER_DATASOURCE_PASSWORD=<私有部署仓库中可写真实值；公开前必须清理>
REDIS_HOST=host.docker.internal
REDIS_PORT=6379
REDIS_PASSWORD=<如服务器 Redis 无密码则留空>
```

## 前端运行设计

前端推荐构建为静态文件，由 Nginx 统一入口提供：

```text
浏览器 -> Nginx 前端容器 :80 -> 静态文件
浏览器 -> Nginx 前端容器 :80/admin-api -> 后端容器 server:48080/admin-api
```

这样可以避免：

- 浏览器直接访问 `48080` 带来的跨域问题。
- 生产环境暴露多个公网端口。
- 前端构建时把后端内网地址硬编码到浏览器里。

本地开发可以先保留前端外部端口 `8080`，服务器正式部署可以由服务器现有 Nginx 反代到前端容器的内部端口。

## 需要确认的真实值

启动容器前需要确认这些值，不能猜：

- MySQL 数据库名，当前项目默认通常是 `ruoyi-vue-pro`。
- MySQL 用户名。
- MySQL 密码。
- Redis 是否有密码。
- 服务器 Docker 实际运行环境是 Windows Docker Desktop、WSL Docker，还是 Linux Docker。
- 服务器现有 Nginx 准备把哪个域名或路径反代到前端容器。
- 本地前端端口是否使用 `8080`，还是换成其他端口避免冲突。

## 下一步执行计划

### Task 1: 创建独立部署目录

**Files:**

- Create: `/Volumes/LVLIAN_1T/yudao/yudao-deploy/docker-compose.local-tunnel.yml`
- Create: `/Volumes/LVLIAN_1T/yudao/yudao-deploy/docker-compose.server.yml`
- Create: `/Volumes/LVLIAN_1T/yudao/yudao-deploy/.env.local-tunnel.example`
- Create: `/Volumes/LVLIAN_1T/yudao/yudao-deploy/.env.server.example`

- [ ] 写入本地隧道 compose，只启动后端和前端，不启动 MySQL/Redis。
- [ ] 本地隧道 compose 的 MySQL 必须连接 `host.docker.internal:13306`。
- [ ] 本地隧道 compose 的 Redis 必须连接 `host.docker.internal:16379`。
- [ ] 写入服务器 compose，只启动后端和前端，不启动 MySQL/Redis。
- [ ] `.env` 示例文件只放变量名和示例地址；真实 `.env.local-tunnel` 和 `.env.server` 只允许留在当前私有部署仓库。

### Task 2: 创建后端容器构建入口

**Files:**

- Create: `/Volumes/LVLIAN_1T/yudao/yudao-deploy/backend/Dockerfile`

- [ ] 优先使用项目已有 Java 8 runtime 思路。
- [ ] 明确 jar 来源为 `ruoyi-vue-pro/yudao-server/target/yudao-server.jar`。
- [ ] 保持后端端口 `48080`。

### Task 3: 创建前端容器构建入口

**Files:**

- Create: `/Volumes/LVLIAN_1T/yudao/yudao-deploy/frontend/Dockerfile`
- Create: `/Volumes/LVLIAN_1T/yudao/yudao-deploy/frontend/nginx.conf`

- [ ] 使用 Node 20 以上镜像构建 `yudao-ui-admin-vue3`。
- [ ] 使用 pnpm 安装依赖并执行构建。
- [ ] 使用 Nginx 镜像运行静态文件。
- [ ] 在 Nginx 中把 `/admin-api` 反代到后端容器 `server:48080`。

### Task 4: 本地验证

**Commands:**

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./start-ssh-tunnel.sh
```

```bash
cd /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac
./test-ssh-tunnel.sh
```

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
mvn -pl yudao-server -am -DskipTests package
```

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/start-local-tunnel-stack.sh
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 server
```

### Task 5: 服务器迁移

**Commands:**

```bash
cd /path/to/yudao-deploy
docker compose --env-file .env.server -f docker-compose.server.yml up -d --build --pull missing
docker compose --env-file .env.server -f docker-compose.server.yml ps
```

- [ ] 服务器 `.env.server` 使用服务器本机 MySQL/Redis 地址。
- [ ] 服务器现有 Nginx 只反代前端入口，不直接暴露 MySQL/Redis。
- [ ] 确认公网只开放必要 HTTP/HTTPS/SSH 端口。
