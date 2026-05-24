# Docker 部署记录与执行方案

## 关键结论

本项目后端不能使用 `YunaiV/ruoyi-vue-pro.git` 默认 `master` 分支。默认分支是 Java 8 / Spring Boot 2.x / Flowable 6.x 方向，连接服务器现有 Flowable 7 数据库会出错。

当前正确方案：

```text
后端仓库: YunaiV/ruoyi-vue-pro.git
后端分支: master-jdk17
Java 构建镜像: maven:latest
Java 运行镜像: eclipse-temurin:latest
前端构建镜像: node:latest
前端运行镜像: nginx:latest
Redis 镜像: redis:latest
SSH 隧道镜像: ssh-tunnel-client:local，基于 alpine:latest，只安装 openssh-client
Spring Boot: 3.5.x
Flowable Maven artifact: 7.2.0
服务器数据库 Flowable schema: 7.2.0.2
```

`node:latest` 当前不假设内置 `corepack`，前端 Dockerfile 使用官方 Node 镜像自带的 `npm` 安装固定版本 `pnpm`。

`7.2.0.2` 是数据库 schema 版本，不是 Maven 依赖版本；依赖版本使用项目里的 `flowable.version=7.2.0`。

## 目录

```text
/Volumes/LVLIAN_1T/yudao
├── ruoyi-vue-pro/              # 后端，必须是 master-jdk17
├── yudao-ui-admin-vue3/        # 前端
└── yudao-deploy/               # 当前部署适配层
```

## 本地 Docker 架构

本地开发连接真实服务器上的 MySQL，但不在 Mac 上直接发布数据库端口给 Docker 使用。Redis 使用本地 Docker 容器。当前 compose 使用 Docker 内部 sidecar 只转发 MySQL：

```text
frontend -> server:48080
server   -> ssh-tunnel:3306 -> SSH -> 服务器 127.0.0.1:3306
server   -> redis:6379
```

本地启动的服务：

```text
ssh-tunnel: 内部 SSH 隧道，不发布端口
redis: 官方 redis:latest，Docker 内部服务，不发布端口
server: Java 后端 yudao-server，监听 48080
frontend: Nginx 前端，发布 2828
```

`ssh-tunnel` 不使用 Maven 镜像。它使用部署仓内的 `ssh-tunnel/Dockerfile` 构建单一功能小镜像：

```dockerfile
FROM alpine:latest
RUN apk add --no-cache openssh-client
```

前端容器会挂载 `frontend/nginx.conf` 到 `/etc/nginx/conf.d/default.conf`。
配置里使用 Docker DNS `127.0.0.11` 动态解析 `server:48080`；不要改回静态 `proxy_pass http://server:48080/...`，否则后端容器重建后 Nginx 可能继续使用旧 IP，表现为大量 502。

因为 compose 的 build context 是 `/Volumes/LVLIAN_1T/yudao`，必须保留 Dockerfile 专属 ignore 文件：

```text
yudao-deploy/frontend/Dockerfile.dockerignore
yudao-deploy/backend/Dockerfile.dockerignore
```

前端 ignore 文件会排除 `yudao-ui-admin-vue3/node_modules`、`.git`、`dist*` 等目录，避免构建上下文过大或把本机依赖复制进 Linux 镜像。
后端 ignore 文件只保留 `ruoyi-vue-pro/yudao-server/target/yudao-server.jar`，用于运行镜像构建。

前端 Docker 构建默认带两个参数，避免容器内生产构建内存过高：

```text
FRONTEND_NODE_OPTIONS=--max-old-space-size=1536
FRONTEND_VITE_BUILD_EXTRA_ARGS=--minify esbuild
```

前端 Vite 变量是构建时变量，部署时通过 `yudao-deploy` 的 `.env.local-tunnel` / `.env.server` 注入，不通过修改 `yudao-ui-admin-vue3/.env` 完成：

```text
FRONTEND_APP_TITLE=南山小平台
FRONTEND_DEFAULT_LOGIN_TENANT=南山
FRONTEND_DEFAULT_LOGIN_USERNAME=
FRONTEND_DEFAULT_LOGIN_PASSWORD=
```

如果服务器资源充足，也可以把 `FRONTEND_VITE_BUILD_EXTRA_ARGS` 清空，让项目继续使用 `vite.config.ts` 里的默认压缩配置。

本地不启动：

```text
MySQL 容器
单独 BPM 容器
```

## 本地环境变量要点

`.env.local-tunnel` 里后端数据地址应为：

```text
MASTER_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
SLAVE_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
REDIS_HOST=redis
REDIS_PORT=6379
```

同时提供 SSH sidecar 所需信息：

```text
SSH_TUNNEL_HOST=120.236.17.146
SSH_TUNNEL_PORT=2222
SSH_TUNNEL_USER=Administrator
SSH_TUNNEL_KEY_FILE=/Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac/keys/ssh_tunnel_120_236_17_146
SSH_TUNNEL_KNOWN_HOSTS_FILE=/Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac/known_hosts
```

## Java17 / Spring Boot 3 Redis 配置

Java17 分支使用 Spring Boot 3，Redis 配置不能只传老的 `spring.redis.*`。compose 必须同时传：

```text
--spring.data.redis.host
--spring.data.redis.port
--spring.data.redis.database
--spring.redis.host
--spring.redis.port
--spring.redis.database
```

只传 `spring.redis.*` 时，Redisson 会继续尝试连接默认 `127.0.0.1:6379`，后端启动失败。

## BPM 启用

BPM 跟随 `yudao-server` 单体后端启动，不需要单独容器。

重新克隆或更新后端后，确认两处：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/pom.xml
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/pom.xml
```

根 `pom.xml`：

```xml
<module>yudao-module-bpm</module>
```

`yudao-server/pom.xml`：

```xml
<dependency>
    <groupId>cn.iocoder.boot</groupId>
    <artifactId>yudao-module-bpm</artifactId>
    <version>${revision}</version>
</dependency>
```

## 构建后端

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/build-backend-jar-with-docker.sh
```

这个脚本必须使用：

```text
maven:latest
```

运行镜像必须使用：

```text
eclipse-temurin:latest
```

## 启动本地部署

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/start-local-tunnel-stack.sh
```

或直接：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml up -d --pull always --build --force-recreate
```

访问：

```text
前端: http://127.0.0.1:2828
后端: http://127.0.0.1:48080
```

查看：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 ssh-tunnel
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 redis
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 server
```

## 服务器部署

服务器正式部署不使用 SSH 隧道。服务器形态：

```text
server: Docker 容器
frontend: Docker 容器
MySQL: 服务器宿主机 3306
Redis: 服务器宿主机 6379
```

容器内部的 `127.0.0.1` 是容器自己，不是服务器宿主机。因此 `.env.server` 默认使用：

```text
MASTER_DATASOURCE_URL=jdbc:mysql://host.docker.internal:3306/ruoyi-vue-pro?...
REDIS_HOST=host.docker.internal
REDIS_PORT=6379
```

服务器部署时，前端容器发布 `0.0.0.0:2828` 作为唯一外部入口。
容器内 Nginx 负责把 `/admin-api`、`/app-api` 等接口代理到 Docker 内部 `server:48080`。
后端 `48080` 默认只绑定 `127.0.0.1`，不作为公网入口。

```text
http://服务器IP:2828
```

不要把 MySQL `3306` 或 Redis `6379` 暴露到公网。

## 当前实测记录

验证日期：`2026-05-24`

```text
后端分支: master-jdk17
后端 commit: 74b73e4c77
后端源码改动: 只打开 BPM module 和 yudao-server BPM dependency
Jar 构建: 成功
Jar 大小: 172M
Jar 内关键依赖:
  spring-boot-3.5.14.jar
  flowable-engine-7.2.0.jar
  flowable-spring-7.2.0.jar
Docker 镜像构建: 成功
前端 Docker 构建: 使用 Dockerfile.dockerignore 排除 node_modules/.git，使用 esbuild 压缩
容器:
  yudao-ssh-tunnel-local Up
  yudao-backend-local Up 127.0.0.1:48080->48080
  yudao-frontend-local Up 127.0.0.1:2828->80
后端日志:
  {dataSource-1,master} inited
  Redisson 4.3.1
  Tomcat started on port 48080
  Started YudaoServerApplication
前端:
  curl -I http://127.0.0.1:2828/ -> 200 OK
  GET http://127.0.0.1:2828/admin-api/system/dict-data/simple-list -> 200 + {"code":401,...}
后端:
  POST http://127.0.0.1:48080/admin-api/system/captcha/get -> repCode=0000
浏览器巡检:
  57/57 个真实菜单页面打开成功
  doc-alert 文档提示文本残留 0
  控制台错误 0，页面异常 0，站内 5xx 响应 0
  Nginx 无 500/502/503/504 或 upstream 连接失败
  后端无 SQL 字段缺失、Flowable、Redis 连接类硬错误
```
