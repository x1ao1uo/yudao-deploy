# 本地 Docker UI 巡检记录

时间：2026-05-24 02:52 CST

## 结论

- 登录方式：租户“南山”，用户 `admin`。
- 巡检范围：复用正式菜单巡检中的 57 个可见菜单页面，当前入口为 `http://127.0.0.1:2828`。
- 浏览器结果：57/57 页面打开成功。
- 浏览器控制台错误：0。
- 页面异常：0。
- 站内 5xx 响应：0。
- `doc-alert` 文档提示文本残留：0。
- Nginx 日志：巡检期间无 `500` / `502` / `503` / `504`，无 `connect() failed`，无 upstream 解析失败。
- 后端日志：巡检期间无 SQL 字段缺失、表缺失、Flowable、Redis 连接类硬错误。

## 502 根因

前端 Nginx 原来使用静态 `proxy_pass http://server:48080/...`。
后端容器重建后，`server` 的 Docker 内网 IP 从旧地址变成新地址，但 Nginx 仍继续请求旧 IP，日志表现为：

```text
connect() failed (111: Connection refused) while connecting to upstream
upstream: "http://172.21.0.2:48080/..."
```

当时 `172.21.0.2` 已经是 `ssh-tunnel` 容器，不是后端容器，所以会大量 502。

## 修复

- `frontend/nginx.conf` 增加 Docker DNS resolver：`resolver 127.0.0.11 valid=10s ipv6=off;`
- 代理目标改为变量：`set $backend server:48080; proxy_pass http://$backend;`
- `docker-compose.local-tunnel.yml` 和 `docker-compose.server.yml` 挂载 `./frontend/nginx.conf:/etc/nginx/conf.d/default.conf:ro`，后续重启前端不依赖重新构建镜像即可使用新配置。

## 验证命令

```bash
curl -sS -o /tmp/yudao-proxy.out -w '%{http_code}\n' \
  http://127.0.0.1:2828/admin-api/system/dict-data/simple-list

docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --since "$SINCE" frontend \
  | rg '" (500|502|503|504) |connect\(\) failed|no live upstreams|host not found in upstream' || true

docker compose --env-file .env.local-tunnel -f docker-compose.local-tunnel.yml logs --since "$SINCE" server \
  | rg 'BadSqlGrammar|Unknown column|SQLSyntaxErrorException|FlowableException|RedisConnection' || true
```

## 证据文件

- JSON 报告：`reports/ui-audit-local-tunnel-2026-05-24T02-49-56-042Z.json`
- 截图：`reports/ui-audit-2026-05-24T02-49-56-042Z-home.png`
