# 开源库更新后的本地定制重做清单

## 目的

`ruoyi-vue-pro` 和 `yudao-ui-admin-vue3` 都是上游开源项目，后续可能重新克隆、拉取更新或升级大版本。本文件记录当前本地环境需要长期保留的定制点，避免以后重新部署时再从头排查。

原则：

- 只做针对当前部署目标的最小改动。
- 不把一次性调试、兼容性实验、临时绕过方案混进长期定制。
- 每次上游更新后，先按本文件检查，再决定是否重做。

## 当前仓库路径

```text
后端: /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
前端: /Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3
部署: /Volumes/LVLIAN_1T/yudao/yudao-deploy
隧道: /Volumes/LVLIAN_1T/code/ssh-tunnel-config
```

## 1. 后端：启用 BPM 模块

详细文档：

```text
/Volumes/LVLIAN_1T/yudao/yudao-deploy/docs/ruoyi-vue-pro-bpm-enable-notes.md
```

后端长期只保留两处最小源码改动：

1. 根 `pom.xml` 打开 `yudao-module-bpm` module。
2. `yudao-server/pom.xml` 打开 `yudao-module-bpm` dependency。

检查命令：

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
git diff -- pom.xml yudao-server/pom.xml
```

期望只看到：

```diff
-<!--        <module>yudao-module-bpm</module>-->
+        <module>yudao-module-bpm</module>
```

以及 `yudao-server/pom.xml` 里 `cn.iocoder.boot:yudao-module-bpm:${revision}` 依赖从注释恢复为正常依赖。

不要默认保留这些实验改动：

- 不要默认升级 `yudao-dependencies/pom.xml` 的 Flowable 版本。
- 不要默认把 Java 8 runtime 改成 Java 17。
- 不要默认追加 `jakarta.mail-api`。
- 不要默认修改部署目录里的后端 Dockerfile 或 Maven 构建镜像。

已知风险：

服务器现有数据库 Flowable schema 是 `7.2.0.2`，当前开源后端默认 Flowable 是 `6.8.1`。如果继续连接现有服务器数据库，可能启动失败：

```text
Could not update Flowable database schema: unknown version from database: '7.2.0.2'
```

这属于 Flowable 版本/schema 兼容问题，不是前端页面问题，也不是普通字段缺失问题。

## 2. 前端：隐藏 BPM 页面顶部“工作流手册”提示

用户要求隐藏每个相关工作流界面顶部这条文档提示：

```vue
<doc-alert title="工作流手册" url="https://doc.iocoder.cn/bpm/" />
```

当前定位到 6 个位置：

```text
/Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3/src/views/bpm/model/definition/index.vue
/Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3/src/views/bpm/category/index.vue
/Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3/src/views/bpm/group/index.vue
/Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3/src/views/bpm/task/manager/index.vue
/Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3/src/views/bpm/processInstance/report/index.vue
/Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3/src/views/bpm/processInstance/manager/index.vue
```

推荐改法：只注释这条完全匹配的 `doc-alert`，不要改全局 `doc-alert` 组件，不要删除其它更具体的 BPM 文档提示。

示例：

```vue
<!-- <doc-alert title="工作流手册" url="https://doc.iocoder.cn/bpm/" /> -->
```

不要一起处理这些更具体的文档提示，除非用户后续明确要求：

```text
审批接入（业务表单）
审批接入（流程表单）
审批通过、不通过、驳回
审批加签、减签
审批抄送
执行监听器、任务监听器
流程表达式
流程发起、取消、重新发起
```

定位命令：

```bash
cd /Volumes/LVLIAN_1T/yudao
rg -n '<doc-alert title="工作流手册" url="https://doc\.iocoder\.cn/bpm/"' yudao-ui-admin-vue3/src/views/bpm -S
```

改完后的检查命令：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3
rg -n '^\s*<doc-alert title="工作流手册" url="https://doc\.iocoder\.cn/bpm/"' src/views/bpm -S
rg -n '<!--\s*<doc-alert title="工作流手册" url="https://doc\.iocoder\.cn/bpm/"' src/views/bpm -S
```

期望结果：

- 第一条命令没有输出，表示没有未注释的“工作流手册”提示。
- 第二条命令输出 6 条，表示 6 个位置都以注释形式保留了上下文。

## 3. 前端验证

前端项目要求：

```text
Node >= 20.19.0
pnpm >= 8.6.0
```

建议验证命令：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3
pnpm build:local
```

如果只是注释 `doc-alert`，理论上不影响 API、路由、权限或数据流；验证重点是构建能过，以及 BPM 相关页面顶部不再出现“工作流手册”文档提示。

## 4. 本地与服务器部署差异

本地开发阶段使用 SSH 隧道连接服务器已有 MySQL/Redis：

```text
MySQL: host.docker.internal:13306
Redis: host.docker.internal:16379
```

服务器正式部署阶段不走 SSH 隧道，后端容器需要连接服务器宿主机已有 MySQL/Redis。注意容器里的 `127.0.0.1` 是容器自己，不是宿主机；服务器 Docker 访问宿主机服务时通常应使用 `host.docker.internal` 或 Linux 下的 `host-gateway` 配置。

部署细节以这个文档为准：

```text
/Volumes/LVLIAN_1T/yudao/yudao-deploy/docs/docker-deployment-notes.md
```

## 5. 重新克隆后的推荐执行顺序

1. 重新克隆或更新 `ruoyi-vue-pro`、`yudao-ui-admin-vue3`。
2. 先打开后端 BPM module 和 server 依赖。
3. 再按本文件隐藏前端 6 个“工作流手册”提示。
4. 启动或确认 SSH 隧道。
5. 构建后端 jar。
6. 构建前端。
7. 使用 `yudao-deploy` 启动本地 Docker 部署。
8. 如果 BPM 接口异常，优先检查后端日志和 Flowable schema 版本，不要先改前端。

## 6. 快速核对命令

```bash
cd /Volumes/LVLIAN_1T/yudao

# 后端长期定制
git -C ruoyi-vue-pro diff -- pom.xml yudao-server/pom.xml

# 前端工作流手册提示
rg -n '<doc-alert title="工作流手册" url="https://doc\.iocoder\.cn/bpm/"' yudao-ui-admin-vue3/src/views/bpm -S

# 前端构建
cd /Volumes/LVLIAN_1T/yudao/yudao-ui-admin-vue3
pnpm build:local
```
