# 已确认信息与后续需确认项

这份清单用于记录当前 Docker 部署所需的真实环境信息。

## 已确认

```text
后端仓库分支: master-jdk17
MySQL 数据库名: ruoyi-vue-pro
MySQL 用户名: root
MySQL 密码: 已写入 .env.local-tunnel / .env.server
Redis 密码: 无
Redis DB 编号: 0
SSH 隧道端口: 2222
SSH 用户: Administrator
SSH 私钥: /Volumes/LVLIAN_1T/code/ssh-tunnel-config/客户端/mac/keys/id_ed25519_120_236_17_146
```

## 本地 Docker 数据链路

本地 compose 使用内部 `ssh-tunnel` sidecar，不要求先手动启动 Mac 上的 `127.0.0.1:13306` 和 `127.0.0.1:16379`。

```text
server -> ssh-tunnel:3306 -> SSH -> 服务器 127.0.0.1:3306
server -> ssh-tunnel:6379 -> SSH -> 服务器 127.0.0.1:6379
```

本地 `.env.local-tunnel` 应保持：

```text
MASTER_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
SLAVE_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
REDIS_HOST=ssh-tunnel
REDIS_PORT=6379
```

## 后续服务器部署前再确认

这些不是当前本地跑通的阻塞项，但上服务器前需要确认：

```text
服务器 Docker 运行位置：Windows Docker Desktop / WSL Docker / Linux Docker
服务器现有 Nginx 要代理的域名：
服务器现有 Nginx 要代理的路径：
服务器前端公网入口是否使用 2828：
服务器是否只保留公网 HTTP/HTTPS/SSH，不开放 3306/6379：
```

服务器正式部署不走 SSH 隧道。后端容器访问服务器宿主机 MySQL/Redis 时，默认使用：

```text
MySQL: host.docker.internal:3306
Redis: host.docker.internal:6379
```

只有后端直接跑在服务器宿主机进程里，而不是 Docker 容器里时，才使用 `127.0.0.1:3306` 和 `127.0.0.1:6379`。
