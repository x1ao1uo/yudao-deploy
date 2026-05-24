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

## 2. 前端：隐藏所有 doc-alert 文档提示

用户要求隐藏所有页面顶部的文档提示，标签形态包括单行和多行：

```vue
<doc-alert title="工作流手册" url="https://doc.iocoder.cn/bpm/" />

<doc-alert
  title="审批转办、委派、抄送"
  url="https://doc.iocoder.cn/bpm/task-delegation-and-cc/"
/>
```

推荐改法：

```vue
<!-- <doc-alert title="工作流手册" url="https://doc.iocoder.cn/bpm/" /> -->

<!-- <doc-alert
  title="审批转办、委派、抄送"
  url="https://doc.iocoder.cn/bpm/task-delegation-and-cc/"
/> -->
```

不要改全局 `doc-alert` 组件；只注释调用处。当前实测共有 `270` 个 `doc-alert` 标签，均已注释。

检查：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3
node <<'NODE'
const fs = require('fs');
const path = require('path');
const root = 'src';
const tagRe = /<doc-alert\b[\s\S]*?\/>/g;
function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else if (entry.isFile() && ['.vue', '.ts', '.tsx'].includes(path.extname(entry.name))) out.push(p);
  }
  return out;
}
function inComment(text, index) {
  const open = text.lastIndexOf('<!--', index);
  const close = text.lastIndexOf('-->', index);
  return open !== -1 && open > close;
}
let total = 0;
let bare = [];
for (const file of walk(root)) {
  const text = fs.readFileSync(file, 'utf8');
  for (const m of text.matchAll(tagRe)) {
    total++;
    if (!inComment(text, m.index)) bare.push(file);
  }
}
console.log({ total, bareCount: bare.length });
NODE
```

期望：

```text
{ total: 270, bareCount: 0 }
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

前端 Nginx 必须保留 Docker DNS 动态解析，避免后端容器重建后继续代理到旧 IP 导致 502：

```text
frontend/nginx.conf:
  resolver 127.0.0.11 valid=10s ipv6=off;
  set $backend server:48080;
  proxy_pass http://$backend;

docker-compose.local-tunnel.yml:
  ./frontend/nginx.conf:/etc/nginx/conf.d/default.conf:ro

docker-compose.server.yml:
  ./frontend/nginx.conf:/etc/nginx/conf.d/default.conf:ro
```

## 4. 推荐执行顺序

1. 克隆后端 `master-jdk17`。
2. 同步或克隆前端。
3. 打开后端 BPM module 和 server dependency。
4. 注释前端全部 `doc-alert` 文档提示。
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

curl -I http://127.0.0.1:2828/
curl -sS -X POST http://127.0.0.1:48080/admin-api/system/captcha/get \
  -H 'tenant-id: 1' \
  -H 'Content-Type: application/json' \
  -d '{}'
```

当前健康结果：

```text
前端 200 OK
后端 captcha/get 返回 repCode=0000
前端代理 /admin-api/system/dict-data/simple-list 返回 200 + 未登录 JSON，不再 502
真实浏览器菜单巡检 57/57 通过，控制台错误 0，页面异常 0，站内 5xx 响应 0，doc-alert 文档提示文本残留 0
```

`repCode=0000` 表示后端、MySQL、Redis、验证码缓存链路都已经可用。
