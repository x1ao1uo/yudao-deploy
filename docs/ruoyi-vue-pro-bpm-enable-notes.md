# RuoYi Vue Pro BPM 后端最小改动记录

## 目的

这份文档只记录这次为了让 `ruoyi-vue-pro` 后端启用工作流 BPM 所需的最小源码改动。以后上游开源库更新、重新拉取或重新编译运行时，先按这份记录恢复改动，不要把本次调试过程里的实验性升级一起带回去。

当前结论：只针对性打开 BPM 模块和 `yudao-server` 对 BPM 模块的依赖。

## 必须保留的源码改动

### 1. 根 `pom.xml` 打开 BPM module

文件：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/pom.xml
```

把这一行从注释状态：

```xml
<!--        <module>yudao-module-bpm</module>-->
```

改成：

```xml
        <module>yudao-module-bpm</module>
```

### 2. `yudao-server/pom.xml` 打开 BPM 依赖

文件：

```text
/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-server/pom.xml
```

在“工作流。默认注释，保证编译速度”下面，把 BPM 依赖从注释状态恢复为正常依赖：

```xml
        <dependency>
            <groupId>cn.iocoder.boot</groupId>
            <artifactId>yudao-module-bpm</artifactId>
            <version>${revision}</version>
        </dependency>
```

## 不要默认保留的实验改动

这次排查过程中验证过一些兼容性方案，但它们不是最小修复。除非后续明确决定做框架迁移，否则不要默认改这些地方：

- 不要默认修改 `/Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro/yudao-dependencies/pom.xml` 里的 `flowable.version`。
- 不要默认把后端运行环境从 Java 8 改成 Java 17。
- 不要默认给 BPM 模块或 server 模块追加 `jakarta.mail-api`。
- 不要默认修改 `/Volumes/LVLIAN_1T/yudao/yudao-deploy/backend/Dockerfile` 的基础镜像。
- 不要默认修改 `/Volumes/LVLIAN_1T/yudao/yudao-deploy/scripts/build-backend-jar-with-docker.sh` 的 Maven/JDK 镜像。

原因：这些属于“让当前远程数据库的 Flowable 7.x schema 强行兼容当前开源代码”的迁移方向，影响面比启用 BPM 模块大很多，后续容易和上游代码不兼容。

## 已确认的问题根因

最开始工作流程页面报错的直接原因不是缺少数据库字段，而是当前开源仓库默认把 BPM 模块关闭了：

- 根 `pom.xml` 里 `yudao-module-bpm` 被注释。
- `yudao-server/pom.xml` 里 `yudao-module-bpm` 依赖被注释。
- 后端未加载 BPM controller，所以 `/admin-api/bpm/**` 接口不可用。

打开 BPM module 和依赖后，BPM controller 才会进入后端应用。

## 当前远程数据库兼容性提醒

本地开发现在通过 SSH 隧道连接服务器已有 MySQL/Redis：

```text
MySQL: host.docker.internal:13306
Redis: host.docker.internal:16379
```

服务器上的现有数据库已经有 Flowable 表，并且实际 schema 版本是：

```text
7.2.0.2
```

但当前 `ruoyi-vue-pro` 开源仓库默认使用的 Flowable 是：

```text
6.8.1
```

因此，最小 BPM 改动可以让源码编译包含 BPM 模块，但如果继续连接这套已有远程数据库，后端启动时可能失败：

```text
Could not update Flowable database schema: unknown version from database: '7.2.0.2'
```

这不是“少打开一个模块”的问题，而是后端 Flowable 版本和数据库 Flowable schema 版本不匹配。

## 后续正确选择

如果要继续使用服务器老版本系统的同一个数据库，推荐优先选择：

1. 找到和这套数据库匹配的后端源码版本，再部署。
2. 或者给当前开源仓库准备一套独立数据库，让 Flowable 6.8.1 自己初始化表结构。
3. 如果必须让当前开源仓库连接现有 Flowable 7.2.0.2 数据库，需要单独规划 Java 17 + Flowable 7 迁移，不能作为这次最小 BPM 开启动作混进去。

当前推荐是先保留最小改动，不做大范围框架迁移。

## 编译命令

直接在后端仓库编译：

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
mvn -pl yudao-server -am -DskipTests package
```

如果使用部署目录里的 Docker 构建脚本：

```bash
cd /Volumes/LVLIAN_1T/yudao/yudao-deploy
./scripts/build-backend-jar-with-docker.sh
```

## 更新开源库后的检查清单

重新拉取或更新 `ruoyi-vue-pro` 后，先检查：

```bash
cd /Volumes/LVLIAN_1T/yudao/ruoyi-vue-pro
git diff -- pom.xml yudao-server/pom.xml
```

期望只看到这两类改动：

- `pom.xml` 打开 `<module>yudao-module-bpm</module>`。
- `yudao-server/pom.xml` 打开 `yudao-module-bpm` dependency。

同时确认没有无意中带入这些改动：

```bash
git diff -- yudao-dependencies/pom.xml
git diff -- yudao-module-bpm/pom.xml
git diff -- ../yudao-deploy/backend/Dockerfile
git diff -- ../yudao-deploy/scripts/build-backend-jar-with-docker.sh
```

如果这些文件出现改动，先确认是不是明确要做 Flowable/JDK 迁移；如果不是，就不应该保留。

## API 验证点

只有在后端 Flowable 版本和数据库 schema 版本匹配时，才继续验证 BPM 页面接口。可以重点看这些接口是否返回 `code=0`：

```text
/admin-api/bpm/model/list
/admin-api/bpm/form/page
/admin-api/bpm/task/todo-page
```

如果这些接口仍然失败，先看后端启动日志和 Flowable schema 版本，不要先猜前端页面问题。
