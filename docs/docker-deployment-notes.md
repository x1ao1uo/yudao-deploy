# Docker 部署记录与执行方案

## 关键结论

本项目后端不能使用 `YunaiV/ruoyi-vue-pro.git` 默认 `master` 分支。默认分支是 Java 8 / Spring Boot 2.x / Flowable 6.x 方向，连接服务器现有 Flowable 7 数据库会出错。

当前正确方案：

```text
后端仓库: YunaiV/ruoyi-vue-pro.git
后端分支: master-jdk17
Java 构建镜像: maven:3.9.9-eclipse-temurin-17
Java 运行镜像: eclipse-temurin:17-jre
Spring Boot: 3.5.x
Flowable Maven artifact: 7.2.0
服务器数据库 Flowable schema: 7.2.0.2
```

`7.2.0.2` 是数据库 schema 版本，不是 Maven 依赖版本；依赖版本使用项目里的 `flowable.version=7.2.0`。

## 目录

```text
/Volumes/LVLIAN_1T/yudao
├── ruoyi-vue-pro/              # 后端，必须是 master-jdk17
├── yudao-ui-admin-vue3/        # 前端
└── yudao-deploy/               # 当前部署适配层
```

## 本地 Docker 架构

本地开发连接真实服务器上的 MySQL/Redis，但不在 Mac 上直接发布数据库端口给 Docker 使用。当前 compose 使用 Docker 内部 sidecar：

```text
frontend -> server:48080
server   -> ssh-tunnel:3306 -> SSH -> 服务器 127.0.0.1:3306
server   -> ssh-tunnel:6379 -> SSH -> 服务器 127.0.0.1:6379
```

本地启动的服务：

```text
ssh-tunnel: 内部 SSH 隧道，不发布端口
server: Java17 后端 yudao-server，监听 48080
frontend: Nginx 前端，监听 8080
```

前端容器会挂载 `frontend/nginx.conf` 到 `/etc/nginx/conf.d/default.conf`。
配置里使用 Docker DNS `127.0.0.11` 动态解析 `server:48080`；不要改回静态 `proxy_pass http://server:48080/...`，否则后端容器重建后 Nginx 可能继续使用旧 IP，表现为大量 502。

本地不启动：

```text
MySQL 容器
Redis 容器
单独 BPM 容器
```

## 本地环境变量要点

`.env.local-tunnel` 里后端数据地址应为：

```text
MASTER_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
SLAVE_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
REDIS_HOST=ssh-tunnel
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
maven:3.9.9-eclipse-temurin-17
```

运行镜像必须使用：

```text
eclipse-temurin:17-jre
```

## 启动本地部署

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/start-local-tunnel-stack.sh
```

或直接：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml up -d --build
```

访问：

```text
前端: http://127.0.0.1:8080
后端: http://127.0.0.1:48080
```

查看：

```bash
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 ssh-tunnel
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

服务器已有 Nginx 只需要反代到前端容器端口，例如：

```text
http://127.0.0.1:18080
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
容器:
  yudao-ssh-tunnel-local Up
  yudao-server-local Up 127.0.0.1:48080->48080
  yudao-admin-local Up 127.0.0.1:8080->80
后端日志:
  {dataSource-1,master} inited
  Redisson 4.3.1
  Tomcat started on port 48080
  Started YudaoServerApplication
前端:
  curl -I http://127.0.0.1:8080/ -> 200 OK
  GET http://127.0.0.1:8080/admin-api/system/dict-data/simple-list -> 200 + {"code":401,...}
后端:
  POST http://127.0.0.1:48080/admin-api/system/captcha/get -> repCode=0000
浏览器巡检:
  57/57 个真实菜单页面打开成功
  Nginx 无 500/502/503/504 或 upstream 连接失败
  后端无 SQL 字段缺失、Flowable、Redis 连接类硬错误
```
