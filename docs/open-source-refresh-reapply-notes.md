# 开源库更新后的本地定制重做清单

## 目的

`ruoyi-vue-pro` 和 `yudao-ui-admin-vue3` 都是上游开源项目。以后重新克隆、拉取更新或升级大版本时，按本文恢复当前环境需要的定制点。

## 重新克隆后端

后端必须克隆 Java17 分支：

```bash
cd /Volumes/LVLIAN_1T/yudao
git clone --branch master-jdk17 --single-branch https://github.com/YunaiV/ruoyi-vue-pro.git ruoyi-vue-pro
```

不要使用默认 `master`。默认 `master` 是 Java8 / Spring Boot 2.x / Flowable 6.x 方向，和服务器现有 Flowable 7 数据库不匹配。

当前验证过的基线：

```text
分支: master-jdk17
commit: 74b73e4c77
Java: 17
Spring Boot: 3.5.x
Flowable dependency: 7.2.0
服务器 Flowable schema: 7.2.0.2
```

## 1. 后端：启用 BPM 模块

后端源码长期只保留两处改动：

1. 根 `pom.xml` 打开 `yudao-module-bpm` module。
2. `yudao-server/pom.xml` 打开 `yudao-module-bpm` dependency。

检查：

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
git diff -- pom.xml yudao-server/pom.xml
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

## 2. 前端：隐藏 BPM 页面顶部“工作流手册”提示

用户要求隐藏每个相关工作流界面顶部这条文档提示：

```vue
<doc-alert title="工作流手册" url="https://doc.iocoder.cn/bpm/" />
```

当前定位到 6 个位置：

```text
src/views/bpm/model/definition/index.vue
src/views/bpm/category/index.vue
src/views/bpm/group/index.vue
src/views/bpm/task/manager/index.vue
src/views/bpm/processInstance/report/index.vue
src/views/bpm/processInstance/manager/index.vue
```

推荐改法：

```vue
<!-- <doc-alert title="工作流手册" url="https://doc.iocoder.cn/bpm/" /> -->
```

不要改全局 `doc-alert` 组件，也不要删除其它更具体的 BPM 文档提示。

检查：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3
rg -n '^\s*<doc-alert title="工作流手册" url="https://doc\.iocoder\.cn/bpm/"' src/views/bpm -S
rg -n '<!--\s*<doc-alert title="工作流手册" url="https://doc\.iocoder\.cn/bpm/"' src/views/bpm -S
```

期望：

```text
未注释命令: 无输出
已注释命令: 6 条
```

## 3. 部署层：Java17 和 Docker 隧道

部署层必须保留 Java17：

```text
backend/Dockerfile: eclipse-temurin:17-jre
scripts/build-backend-jar-with-docker.sh: maven:3.9.9-eclipse-temurin-17
```

本地开发 compose 使用 `ssh-tunnel` sidecar：

```text
ssh-tunnel:3306 -> 服务器 127.0.0.1:3306
ssh-tunnel:6379 -> 服务器 127.0.0.1:6379
```

本地 `.env.local-tunnel` 应使用：

```text
MASTER_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
SLAVE_DATASOURCE_URL=jdbc:mysql://ssh-tunnel:3306/ruoyi-vue-pro?...
REDIS_HOST=ssh-tunnel
REDIS_PORT=6379
```

Java17 / Spring Boot 3 下，compose 必须传 `spring.data.redis.*`，不能只传老的 `spring.redis.*`。

## 4. 推荐执行顺序

1. 克隆后端 `master-jdk17`。
2. 同步或克隆前端。
3. 打开后端 BPM module 和 server dependency。
4. 注释前端 6 个“工作流手册”提示。
5. 在 `yudao-deploy` 构建后端 jar。
6. 启动本地 Docker compose。
7. 检查 `ssh-tunnel`、`server`、`frontend` 都为 Up。
8. 看后端日志是否出现 `Started YudaoServerApplication`。

## 5. 验证命令

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/build-backend-jar-with-docker.sh
./scripts/start-local-tunnel-stack.sh

docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml ps
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --tail=120 server

curl -I http://127.0.0.1:8080/
curl -sS -X POST http://127.0.0.1:48080/admin-api/system/captcha/get \
  -H 'tenant-id: 1' \
  -H 'Content-Type: application/json' \
  -d '{}'
```

当前健康结果：

```text
前端 200 OK
后端 captcha/get 返回 repCode=0000
```

`repCode=0000` 表示后端、MySQL、Redis、验证码缓存链路都已经可用。
