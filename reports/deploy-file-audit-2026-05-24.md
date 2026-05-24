# yudao-deploy 文件审计记录

时间：2026-05-24

审计背景：后端已切换为 `YunaiV/ruoyi-vue-pro.git` 的 `master-jdk17` 分支，部署层需要按 Java17 / Spring Boot 3 / Flowable 7.2.0 重新核对。

## 当前后端基线

```text
后端路径：/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
后端分支：master-jdk17
后端提交：74b73e4c77
Java：17
BPM 启用：根 pom.xml + yudao-server/pom.xml 两处最小改动
Jar 关键依赖：spring-boot-3.5.14.jar、flowable-engine-7.2.0.jar、flowable-spring-7.2.0.jar
```

## 审计结果

| 文件 | 结果 | 说明 |
|---|---|---|
| `.env.local-tunnel` | 已对齐 | 本地真实环境文件；MySQL/Redis 走 `ssh-tunnel` sidecar；前端发布 `127.0.0.1:2828`；包含前端 Docker 构建内存参数。 |
| `.env.local-tunnel.example` | 已对齐 | 本地模板文件；保留 `CHANGE_ME`；适合复制后填写；包含前端 Docker 构建内存参数。 |
| `.env.server` | 已对齐 | 服务器真实环境文件；Docker 后端访问宿主机 MySQL/Redis 使用 `host.docker.internal`；前端发布 `0.0.0.0:2828`。 |
| `.env.server.example` | 已对齐 | 服务器模板文件；保留 `CHANGE_ME`；包含前端 Docker 构建内存参数。 |
| `.gitignore` | 已对齐 | 只忽略 `*.local`；真实 `.env.*` 在此私有部署仓库中按当前约定保留。 |
| `NEED-INFO.md` | 已对齐 | 已确认信息和服务器上线前待确认项仍有效。 |
| `README.md` | 已对齐 | 已写明 `master-jdk17`、Java17 镜像、BPM 两处启用点、sidecar 隧道、2828 前端入口和 Nginx 502 修复。 |
| `backend/Dockerfile` | 已对齐 | 运行镜像为 `eclipse-temurin:17-jre`，Jar 路径仍是 `ruoyi-vue-pro/yudao-server/target/yudao-server.jar`。 |
| `backend/Dockerfile.dockerignore` | 已补齐 | build context 是上级目录；后端镜像只需要 `yudao-server.jar`，避免把无关源码和 `.git` 送进上下文。 |
| `docker-compose.local-tunnel.yml` | 已对齐 | 启动 `ssh-tunnel`、`server`、`frontend`；传入 `spring.data.redis.*` 和 `spring.redis.*`；挂载 Nginx 配置；本地前端发布 `127.0.0.1:2828`。 |
| `docker-compose.server.yml` | 已对齐 | 服务器不走 SSH 隧道；后端容器访问宿主机服务；挂载 Nginx 配置；服务器前端发布 `0.0.0.0:2828`。 |
| `docs/docker-deployment-notes.md` | 已对齐 | Java17、Flowable 7、Nginx 动态解析、57 页面巡检结果均已记录。 |
| `docs/open-source-refresh-reapply-notes.md` | 已修正 | 补入 Nginx Docker DNS 动态解析和 compose 挂载要求。 |
| `docs/ruoyi-vue-pro-bpm-enable-notes.md` | 已对齐 | 只保留 BPM 两处最小后端改动，不再沿用 Java8 patch 路线。 |
| `frontend/Dockerfile` | 已对齐 | 前端构建使用 `node:22-alpine`，运行镜像 `nginx:1.27-alpine`；Docker 默认用 `--minify esbuild` 降低容器构建内存压力。 |
| `frontend/Dockerfile.dockerignore` | 已补齐 | 排除前端 `node_modules`、`.git`、`dist*` 等目录，避免构建上下文过大和本机依赖覆盖容器依赖。 |
| `frontend/nginx.conf` | 已对齐 | 使用 `resolver 127.0.0.11` + `$backend`，避免后端容器重建后的旧 IP 502。 |
| `scripts/build-backend-jar-with-docker.sh` | 已对齐 | Maven 镜像为 `maven:3.9.9-eclipse-temurin-17`。 |
| `scripts/check-local-prereqs.sh` | 已对齐 | 检查 Docker、SSH key、known_hosts、后端 Jar 和 compose 配置。 |
| `scripts/start-local-tunnel-stack.sh` | 已对齐 | 使用本地镜像优先，缺失时按 compose 构建启动。 |
| `reports/ui-audit-local-tunnel-2026-05-24T02-49-56-042Z.json` | 保留 | 当前 2828 入口和全量 doc-alert 注释后的正式浏览器巡检报告，57/57 通过。 |
| `reports/ui-audit-2026-05-24T02-49-56-042Z-home.png` | 保留 | 当前正式巡检的截图证据。 |
| `reports/ui-audit-local-tunnel-2026-05-23T18-52-26-748Z.json` | 保留 | 历史浏览器巡检报告，记录 Java17 后端初次跑通状态。 |
| `reports/ui-audit-2026-05-23T18-52-26-748Z-home.png` | 保留 | 历史巡检截图证据。 |
| `reports/ui-audit-local-tunnel-2026-05-24.md` | 保留 | 502 根因、修复记录和当前 2828 巡检摘要。 |
| `reports/ui-menu-audit-local-tunnel-2026-05-23.json` | 已删除 | 旧报告包含 “BPM 已禁用”、`host.docker.internal:13306` 等 Java17 切换前状态，继续保留会误导。 |

## 额外发现

部署清单现在要求 `yudao-ui-admin-vue3` 中全部 `doc-alert` 文档提示保持注释。当前前端源码共 `270` 个 `doc-alert` 标签，裸露未注释数量为 `0`。

## 验证

```text
docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml config：通过
docker compose --env-file .env.server -f docker-compose.server.yml config：通过
nginx -t：通过
前端代理 /admin-api/system/dict-data/simple-list：200 + 未登录 JSON
正式浏览器巡检报告：57/57 页面通过，控制台错误 0，页面异常 0，站内 5xx 响应 0，doc-alert 文档提示文本残留 0
```
