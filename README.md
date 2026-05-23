# yudao-deploy

这个目录是当前环境专用的 Docker 部署适配层。后端和前端仍然保留在各自上游仓库里，部署、隧道、环境变量和运行文档集中放在这里。

## 当前正确基线

后端必须使用 `YunaiV/ruoyi-vue-pro.git` 的 `master-jdk17` 分支，不要使用默认 `master` 分支。

默认 `master` 是 Java 8 / Spring Boot 2.x / Flowable 6.x 方向，和服务器现有 Flowable 7 系列表不匹配。本目录当前按 Java 17 / Spring Boot 3 / Flowable 7.2.0 部署：

```text
后端分支: master-jdk17
Java 构建镜像: maven:3.9.9-eclipse-temurin-17
Java 运行镜像: eclipse-temurin:17-jre
后端端口: 48080
前端端口: 8080
本地数据连接: Docker 内部 ssh-tunnel sidecar
```

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

本地开发不启动 MySQL 容器、不启动 Redis 容器，也不要求你先手动启动 Mac 上的 `127.0.0.1:13306` / `127.0.0.1:16379` 隧道。

`docker-compose.local-tunnel.yml` 会启动三个服务：

```text
ssh-tunnel: Docker 内部 SSH 隧道，连接服务器 120.236.17.146:2222
server: Java17 后端 yudao-server
frontend: Nginx 前端，反代 /admin-api 到 server:48080
```

`frontend/nginx.conf` 会挂载到前端容器的 `/etc/nginx/conf.d/default.conf`。
Nginx 通过 Docker DNS `127.0.0.11` 动态解析 `server:48080`，避免后端容器重建后继续代理到旧 IP 导致 502。

后端容器连接：

```text
MySQL: ssh-tunnel:3306
Redis: ssh-tunnel:6379
```

这两个端口只在 Docker 网络内部使用，不发布到 Mac 或局域网。

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
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml up -d --build
```

访问：

```text
前端: http://127.0.0.1:8080
后端: http://127.0.0.1:48080
```

查看状态和日志：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 ssh-tunnel
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

服务器已有 Nginx 可以反代到前端容器绑定的本机端口：

```text
http://127.0.0.1:18080
```

不要把 MySQL `3306` 或 Redis `6379` 开到公网。

## 当前验证结论

2026-05-24 已在本机完成验证：

```text
后端 Jar: 构建成功
Jar 内版本: spring-boot-3.5.14, flowable-engine-7.2.0
Docker 服务: ssh-tunnel, server, frontend 均运行
MySQL: 后端日志显示 {dataSource-1,master} inited
Redis: Redisson 4.3.1 初始化成功
后端启动: Started YudaoServerApplication
前端: http://127.0.0.1:8080 返回 200 OK
后端接口: POST http://127.0.0.1:48080/admin-api/system/captcha/get 返回 repCode=0000
前端代理: GET http://127.0.0.1:8080/admin-api/system/dict-data/simple-list 返回 200 + 未登录 JSON，不再 502
浏览器巡检: 57/57 个真实菜单页面打开成功，控制台错误 0
```

详细记录见：

```text
docs/docker-deployment-notes.md
docs/open-source-refresh-reapply-notes.md
docs/ruoyi-vue-pro-bpm-enable-notes.md
```
