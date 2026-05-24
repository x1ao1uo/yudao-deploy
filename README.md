# yudao-deploy

这个目录是当前环境专用的 Docker 部署适配层。后端和前端仍然保留在各自上游仓库里，部署、隧道、环境变量和运行文档集中放在这里。

## 当前正确基线

后端必须使用 `YunaiV/ruoyi-vue-pro.git` 的 `master-jdk17` 分支，不要使用默认 `master` 分支。

默认 `master` 是 Java 8 / Spring Boot 2.x / Flowable 6.x 方向，和服务器现有 Flowable 7 系列表不匹配。本目录当前按 Java 17 / Spring Boot 3 / Flowable 7.2.0 部署：

```text
后端分支: master-jdk17
Java 构建镜像: maven:latest
Java 运行镜像: eclipse-temurin:latest
前端构建镜像: node:latest
前端运行镜像: nginx:latest
Redis 镜像: redis:latest
后端端口: 48080
前端入口端口: 2828
本地数据连接: MySQL 走 Docker 内部 ssh-tunnel sidecar，Redis 走本地 Docker 容器
```

`node:latest` 当前不假设内置 `corepack`，前端 Dockerfile 使用官方 Node 镜像自带的 `npm` 安装指定版本 `pnpm`。

重新克隆后端时使用：

```bash
cd /Volumes/LVLIAN_1T/yudao
git clone --branch master-jdk17 --single-branch https://github.com/YunaiV/ruoyi-vue-pro.git ruoyi-vue-pro
```

## BPM 启用要求

BPM 不是独立 Docker 容器，跟随 `yudao-server` 一起编译和启动。

重新克隆或更新 `ruoyi-vue-pro` 后，只需要确认两处源码改动：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/pom.xml
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/pom.xml
```

根 `pom.xml` 打开：

```xml
<module>yudao-module-bpm</module>
```

`yudao-server/pom.xml` 打开：

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

## 本地 Docker 开发

本地开发不启动 MySQL 容器，也不要求你先手动启动 Mac 上的 `127.0.0.1:13306` 隧道。MySQL 通过 Docker 内部 SSH sidecar 连接服务器，Redis 使用本地 Docker 容器。

`docker-compose.local-tunnel.yml` 会启动四个服务：

```text
ssh-tunnel: Docker 内部 SSH 隧道，只转发服务器 MySQL 3306
redis: 官方 redis:latest，本地 Docker 内部使用，不发布端口
server: Java 后端 yudao-server
frontend: Nginx 前端，反代 /admin-api 到 server:48080
```

本地访问入口是 `127.0.0.1:2828`。服务器访问入口是 `服务器IP:2828`。

`frontend/nginx.conf` 会挂载到前端容器的 `/etc/nginx/conf.d/default.conf`。
Nginx 通过 Docker DNS `127.0.0.11` 动态解析 `server:48080`，避免后端容器重建后继续代理到旧 IP 导致 502。

构建上下文是 `/Volumes/LVLIAN_1T/yudao`，但部署仓提供了 `frontend/Dockerfile.dockerignore` 和 `backend/Dockerfile.dockerignore`。
不要删除这两个文件，否则 Docker 会把前端 `node_modules`、`.git` 等大目录送进构建上下文，前端构建容易内存不足，也可能把本机依赖覆盖到 Linux 容器里。
前端 Docker 构建默认使用 `FRONTEND_NODE_OPTIONS=--max-old-space-size=1536` 和 `FRONTEND_VITE_BUILD_EXTRA_ARGS=--minify esbuild`，用于降低容器内生产构建的内存压力。
前端标题、默认租户、默认账号密码由部署仓环境变量控制，并在 Docker build 时写入 `.env.docker`；不要为了部署去修改 `yudao-ui-admin-vue3/.env`。
本地体验版按用户偏好使用官方 `latest` 镜像，并且 `scripts/start-local-tunnel-stack.sh` 默认每次执行都会 `--pull always --build --force-recreate`。

```text
FRONTEND_APP_TITLE=南山小平台
FRONTEND_DEFAULT_LOGIN_TENANT=南山
FRONTEND_DEFAULT_LOGIN_USERNAME=
FRONTEND_DEFAULT_LOGIN_PASSWORD=
```

后端容器连接：

```text
MySQL: ssh-tunnel:3306
Redis: redis:6379
```

这两个端口只在 Docker 网络内部使用，不发布到 Mac 或局域网。Redis 数据保存在 Docker volume `redis-data`。

## 构建后端 Jar

推荐使用 Docker 版 Maven，避免本机 JDK/Maven 版本不一致：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/build-backend-jar-with-docker.sh
```

期望产物：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/target/yudao-server.jar
```

## 启动本地部署

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/start-local-tunnel-stack.sh
```

直接使用 compose：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml up -d --pull always --build --force-recreate
```

访问：

```text
前端: http://127.0.0.1:2828
后端: http://127.0.0.1:48080
```

查看状态和日志：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 ssh-tunnel
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 redis
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 server
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 frontend
```

## Java17 / Spring Boot 3 配置重点

Spring Boot 3 的 Redis 配置要使用 `spring.data.redis.*`。为了兼容，本目录 compose 同时传：

```text
--spring.data.redis.host
--spring.data.redis.port
--spring.data.redis.database
--spring.redis.host
--spring.redis.port
--spring.redis.database
```

只传老的 `spring.redis.*` 会导致 Redisson 仍然尝试连接 `127.0.0.1:6379`。

## 服务器部署

服务器正式部署不使用 SSH 隧道。你的服务器形态是：

```text
后端 yudao-server: Docker 容器
MySQL: 服务器宿主机 3306
Redis: 服务器宿主机 6379
```

因此 `.env.server` 里不要把数据库地址改成 `127.0.0.1:3306`。在后端容器内部，`127.0.0.1` 是容器自己，不是服务器宿主机。默认使用：

```text
MySQL: host.docker.internal:3306
Redis: host.docker.internal:6379
```

服务器部署时，前端容器发布 `0.0.0.0:2828` 作为唯一外部入口，容器内 Nginx 会把 `/admin-api`、`/app-api` 等接口代理到 Docker 内部 `server:48080`。
后端 `48080` 默认只绑定 `127.0.0.1`，不作为公网入口。

```text
http://服务器IP:2828
```

不要把 MySQL `3306` 或 Redis `6379` 开到公网。

## 当前验证结论

2026-05-24 已在本机完成验证：

```text
后端 Jar: 构建成功
Jar 内版本: spring-boot-3.5.14, flowable-engine-7.2.0
Docker 服务: ssh-tunnel, server, frontend 均运行
前端 Docker 镜像: 构建成功，使用 Dockerfile.dockerignore 排除 node_modules/.git，使用 esbuild 压缩
MySQL: 后端日志显示 {dataSource-1,master} inited
Redis: Redisson 4.3.1 初始化成功
后端启动: Started YudaoServerApplication
前端: http://127.0.0.1:2828 返回 200 OK
后端接口: POST http://127.0.0.1:48080/admin-api/system/captcha/get 返回 repCode=0000
前端代理: GET http://127.0.0.1:2828/admin-api/system/dict-data/simple-list 返回 200 + 未登录 JSON，不再 502
浏览器巡检: 57/57 个真实菜单页面打开成功，控制台错误 0，页面异常 0，站内 5xx 响应 0，doc-alert 文档提示文本残留 0
```

详细记录见：

```text
docs/docker-deployment-notes.md
docs/open-source-refresh-reapply-notes.md
docs/ruoyi-vue-pro-bpm-enable-notes.md
```
