# RuoYi Vue Pro BPM 后端改动记录

## 当前结论

后端必须基于 `master-jdk17` 分支启用 BPM。不要在默认 Java8 `master` 分支上硬升 Java、Spring Boot 或 Flowable。

正确基线：

```text
仓库: https://github.com/YunaiV/ruoyi-vue-pro.git
分支: master-jdk17
Java: 17
Spring Boot: 3.5.x
Flowable dependency: 7.2.0
服务器 Flowable schema: 7.2.0.2
```

## 重新克隆

```bash
cd /Volumes/LVLIAN_1T/yudao
git clone --branch master-jdk17 --single-branch https://github.com/YunaiV/ruoyi-vue-pro.git ruoyi-vue-pro
```

如果 GitHub 网络失败，可以从已有本地备份克隆 `master-jdk17`，但克隆后要把 remote 改回：

```bash
git remote set-url origin https://github.com/YunaiV/ruoyi-vue-pro.git
```

## 必须保留的源码改动

### 1. 根 `pom.xml`

文件：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/pom.xml
```

打开：

```xml
<module>yudao-module-bpm</module>
```

### 2. `yudao-server/pom.xml`

文件：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/pom.xml
```

打开：

```xml
<dependency>
    <groupId>cn.iocoder.boot</groupId>
    <artifactId>yudao-module-bpm</artifactId>
    <version>${revision}</version>
</dependency>
```

检查：

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
git diff -- pom.xml yudao-server/pom.xml
```

期望只有 BPM module 和 BPM dependency 两处源码改动。

## 不要再做的错误路线

不要在默认 `master` 分支上做这些实验性修改：

```text
Java 8 -> Java 17
Spring Boot 2.x -> Spring Boot 3.x
Flowable 6.x -> Flowable 7.x
手动补 jakarta/angus mail 依赖
```

这些不是最小定制，而且容易和上游代码不兼容。正确做法是直接使用上游已有的 `master-jdk17` 分支。

## 构建要求

本地体验版按用户偏好使用官方 `latest` 镜像。后端源码仍然必须是 `master-jdk17` 分支；镜像标签使用 latest 是运行/构建底座策略，不代表改后端源码分支。

```text
/Volumes/LVLIAN_1T/yudao/yudao-deploy/scripts/build-backend-jar-with-docker.sh
  maven:latest

/Volumes/LVLIAN_1T/yudao/yudao-deploy/backend/Dockerfile
  eclipse-temurin:latest
```

构建：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/build-backend-jar-with-docker.sh
```

验证 Jar：

```bash
jar tf /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/target/yudao-server.jar \
  | rg 'BOOT-INF/lib/(flowable-engine|flowable-spring|spring-boot)-'
```

当前实测：

```text
spring-boot-3.5.14.jar
flowable-engine-7.2.0.jar
flowable-spring-7.2.0.jar
```

## 运行验证

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml up -d --pull always --build --force-recreate
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=200 server
```

期望日志：

```text
{dataSource-1,master} inited
Redisson 4.3.1
Tomcat started on port 48080
Started YudaoServerApplication
```

## Java17 分支的 Redis 配置点

Java17 / Spring Boot 3 分支 Redis 配置使用 `spring.data.redis.*`。compose 需要同时传新旧两套键：

```text
--spring.data.redis.host
--spring.data.redis.port
--spring.data.redis.database
--spring.redis.host
--spring.redis.port
--spring.redis.database
```

只传 `spring.redis.*` 会导致 Redisson 仍然连 `127.0.0.1:6379`。

## API 验证点

后端启动后可以先用基础接口确认服务可达：

```bash
curl -sS -X POST http://127.0.0.1:48080/admin-api/system/captcha/get \
  -H 'tenant-id: 1' \
  -H 'Content-Type: application/json' \
  -d '{}'
```

当前返回：

```json
{"repCode":"0000", ...}
```

这说明后端服务已响应，并且验证码链路可用。
