# 需要你提供的信息

这份清单用于把本地 Docker 开发环境真正跑起来。当前约束是：本地 MySQL 和 Redis 都通过 `/Volumes/LVLIAN_1T/code/ssh-tunnel-config` 连接服务器数据，不启动本地 MySQL/Redis 容器。

## 现在必须提供

请按下面格式回复，能填多少填多少；不确定就写“不确定”。

```text
MySQL 数据库名：
MySQL 用户名：
MySQL 密码：
Redis 是否有密码：
Redis 密码：
Redis DB 编号：
远程数据库是否已经导入 ruoyi-vue-pro 的 SQL：
是否确认允许本地后端连接这套真实服务器数据并产生写入：
```

## 当前本机还缺的运行条件

我已经能构建后端 jar 和前后端 Docker 镜像，也已经启动并验证过 SSH 隧道。当前本地后端可以连到远程 MySQL 端口，但 MySQL 认证失败：

```text
Access denied for user 'root'@'localhost'
```

所以当前还缺的是服务器 MySQL 的真实用户名和密码。Redis 已确认无密码，当前配置使用 Redis DB `0`。

检查命令：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/check-local-prereqs.sh
```

## 每一项为什么需要

### MySQL 数据库名

后端默认连接 `ruoyi-vue-pro`。如果服务器上实际库名不同，容器启动后会连错库。

### MySQL 用户名和密码

后端容器启动时必须通过 JDBC 连接远程 MySQL。当前本地容器连接地址固定是：

```text
host.docker.internal:13306
```

这个地址来自 SSH 隧道：

```text
127.0.0.1:13306 -> 服务器 127.0.0.1:3306
```

### Redis 密码和 DB 编号

后端需要 Redis 保存缓存、登录态、验证码等运行数据。当前本地容器连接地址固定是：

```text
host.docker.internal:16379
```

这个地址来自 SSH 隧道：

```text
127.0.0.1:16379 -> 服务器 127.0.0.1:6379
```

如果 Redis 没有密码，写“无密码”。如果不确定 DB 编号，一般先用 `0`。

### 远程数据库是否已经导入 SQL

如果远程 MySQL 里还没有 `ruoyi-vue-pro` 的表结构和初始数据，后端会启动失败或登录不了。项目 SQL 通常在：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/sql/mysql/ruoyi-vue-pro.sql
```

### 是否允许写入真实服务器数据

本地后端连的是服务器真实 MySQL/Redis。启动后可能产生登录日志、缓存、定时任务记录等写入。如果这套库是生产数据，建议先确认备份，或者单独建测试库。

## 后续服务器部署前再确认

这些不是本地跑通的立即阻塞项，但后续上服务器前需要确认：

```text
服务器 Docker 运行位置：Windows Docker Desktop / WSL Docker / Linux Docker
服务器现有 Nginx 要代理的域名：
服务器现有 Nginx 要代理的路径：
服务器前端容器内网端口是否使用 18080：
服务器是否只保留公网 HTTP/HTTPS/SSH，不开放 3306/6379：
```
