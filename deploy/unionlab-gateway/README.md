# UnionLab Gateway 部署指南

本目录包含 UnionLab Gateway（基于 [LiteLLM](https://github.com/BerriAI/litellm)）的 Docker Compose 部署配置，使用外部 PostgreSQL（阿里云 RDS），不启动本地数据库容器。

## 目录结构

```
deploy/unionlab-gateway/
├── README.md                  # 本文档
├── docker-compose.build.yml   # 从源码构建并部署（推荐用于二次开发）
├── docker-compose.yml         # 使用官方预构建镜像快速部署
├── config.yaml                # LiteLLM Proxy 业务配置
├── .env.example               # 环境变量模板（可提交 Git）
├── .env                       # 实际环境变量（含密钥，勿提交）
├── .gitignore                 # 忽略 .env 与 custom-ui/
├── patch-ui-branding.py       # UI 品牌替换脚本
└── custom-ui/                 # UI 构建产物（勿提交，需本地生成）
```

源码仓库根目录为 `app/`（即本目录的上两级 `../..`），构建时会从该路径读取 Dockerfile 与完整代码。

---

## 前置条件

- Docker Engine 与 Docker Compose v2
- 可访问的 PostgreSQL 数据库（当前使用阿里云 RDS）
- RDS 安全组/白名单已放行部署服务器的 IP，端口 `5432`
- 服务器可用磁盘空间 ≥ 5 GB（首次源码构建约需 2–3 GB 镜像空间）

---

## 首次部署

### 1. 配置环境变量

```bash
cd /root/app/litellm/app/deploy/unionlab-gateway
cp .env.example .env
```

编辑 `.env`，至少填写以下项：

| 变量 | 说明 |
|------|------|
| `LITELLM_MASTER_KEY` | Proxy 主密钥，用于 API 鉴权与 Admin UI 登录 |
| `LITELLM_SALT_KEY` | 加密盐值，**部署后不可随意更改** |
| `POSTGRES_USER` | RDS 数据库用户名 |
| `POSTGRES_PASSWORD` | RDS 数据库密码 |
| `POSTGRES_DB` | 数据库名（如 `litellm`） |
| `POSTGRES_HOST` | RDS 连接地址 |

按需填写上游 LLM Provider 的 API Key（`OPENAI_API_KEY` 等）。

### 2. 检查业务配置

按需修改 `config.yaml`（Logo、主题、模型列表等）。`master_key` 从环境变量 `LITELLM_MASTER_KEY` 读取，无需在文件中硬编码。

### 3. 选择部署方式并启动

**方式 A：从源码构建（推荐，含最新代码与 UI 二次开发）**

```bash
docker compose -f docker-compose.build.yml up -d --build
```

**方式 B：使用官方预构建镜像（启动快，版本固定为 v1.89.2）**

```bash
docker compose up -d
```

> 两种方式共用容器名 `unionlab-gateway`，不可同时运行。

### 4. 验证

```bash
# 查看容器状态
docker compose -f docker-compose.build.yml ps

# 健康检查
curl http://127.0.0.1:4000/health/liveliness

# 查看日志
docker compose -f docker-compose.build.yml logs -f unionlab-gateway
```

- 管理 UI：`http://<服务器IP>:4000/ui`
- API 端口：`4000`（`network_mode: host`，直接监听宿主机）

---

## 日常运维

```bash
cd /root/app/litellm/app/deploy/unionlab-gateway

# 修改 config.yaml 或 .env 后重启
docker compose -f docker-compose.build.yml restart

# 拉取最新代码后重新构建部署
cd ../.. && git pull && cd deploy/unionlab-gateway
docker compose -f docker-compose.build.yml up -d --build

# 停止服务
docker compose -f docker-compose.build.yml down

# 完全重建（不使用缓存）
docker compose -f docker-compose.build.yml build --no-cache
docker compose -f docker-compose.build.yml up -d
```

---

## UI 二次开发

UI 源码位于仓库 `ui/litellm-dashboard/`。

### 构建并替换 UI

```bash
# 1. 在源码目录构建 UI
cd /root/app/litellm/app/ui/litellm-dashboard
npm install
npm run build
bash build_ui.sh

# 2. 复制产物到部署目录
cp -r ../../litellm/proxy/_experimental/out/* \
  /root/app/litellm/app/deploy/unionlab-gateway/custom-ui/

# 3. 应用 UnionLab 品牌替换（可选）
cd /root/app/litellm/app/deploy/unionlab-gateway
python3 patch-ui-branding.py
```

### 启用自定义 UI 挂载

**源码构建模式**：编辑 `docker-compose.build.yml`，取消 `custom-ui` volume 注释，并添加环境变量：

```yaml
volumes:
  - ./config.yaml:/app/config.yaml:ro
  - ./custom-ui:/app/litellm/proxy/_experimental/out:ro
environment:
  LITELLM_UI_PATH: /app/litellm/proxy/_experimental/out
```

**预构建镜像模式**：`docker-compose.yml` 已默认挂载 `custom-ui`，修改后直接 `docker compose restart` 即可。

---

## Git 管理说明

| 文件/目录 | 是否提交 Git | 说明 |
|-----------|-------------|------|
| `config.yaml` | ✅ | 业务配置 |
| `docker-compose*.yml` | ✅ | 部署编排 |
| `.env.example` | ✅ | 环境变量模板 |
| `patch-ui-branding.py` | ✅ | 品牌脚本 |
| `.env` | ❌ | 含密钥，已在 `.gitignore` |
| `custom-ui/` | ❌ | 构建产物，已在 `.gitignore` |

提交示例：

```bash
cd /root/app/litellm/app
git add deploy/unionlab-gateway/
git commit -m "update unionlab-gateway deployment config"
git push
```

---

## 注意事项

### 安全

1. **切勿将 `.env` 提交到 Git**，其中包含 `LITELLM_MASTER_KEY`、`LITELLM_SALT_KEY` 和数据库密码。
2. **`LITELLM_SALT_KEY` 一旦用于生产环境后不可更改**，否则已加密存储的数据将无法解密。
3. **`LITELLM_MASTER_KEY` 即为 Admin UI 与 API 的管理员密钥**，请使用足够长度的随机字符串。
4. 生产环境建议在 RDS 前增加 IP 白名单，并定期轮换数据库密码。

### 数据库

1. 容器启动时会自动执行 `prisma migrate deploy` 完成表结构迁移。
2. RDS 用户需具备建表、改表权限（首次部署时）。
3. `DATABASE_URL` 由 `.env` 中的 `POSTGRES_*` 变量拼接，无需在 `.env` 中单独写完整 URL。
4. 不使用本地 Postgres 容器，所有持久化数据存储在 RDS 中。

### 网络与端口

1. 当前使用 `network_mode: host`，容器直接绑定宿主机 `4000` 端口。
2. 确保宿主机防火墙/安全组已放行 `4000` 端口（如需外网访问 UI）。
3. 若改用 bridge 网络，需将 `network_mode: host` 改为 `ports: ["4000:4000"]` 并调整 healthcheck 地址。

### 构建

1. 首次源码构建耗时约 5–15 分钟，取决于网络与 CPU。
2. 构建上下文为仓库根目录 `../..`，Dockerfile 路径为 `docker/Dockerfile.database`。
3. 默认构建会将源码中已有的 UI 静态文件打包进镜像；若需覆盖，使用 `custom-ui` 挂载。

### 升级

1. **源码构建模式**：`git pull` 后执行 `docker compose -f docker-compose.build.yml up -d --build`。
2. **预构建镜像模式**：修改 `docker-compose.yml` 中的 `image` 版本号后 `docker compose pull && docker compose up -d`。
3. 升级前建议备份 RDS 数据库。

### 故障排查

| 现象 | 可能原因 | 处理 |
|------|---------|------|
| 容器反复重启 | RDS 不可达或密码错误 | 检查 `.env` 与 RDS 白名单，`docker compose logs` 查看报错 |
| `Master key is not initialized` | 未配置 `.env` 或未加载 | 确认 `.env` 存在且含 `LITELLM_MASTER_KEY` |
| UI 404 或样式异常 | UI 产物未构建或挂载路径错误 | 重新构建 UI 并检查 `custom-ui/` 目录 |
| 构建失败 | 网络问题或磁盘不足 | 检查 Docker 日志，`df -h` 确认磁盘空间 |

---

## 相关链接

- LiteLLM 官方文档：https://docs.litellm.ai/
- 源码 UI 目录：`../../ui/litellm-dashboard/`
- Docker 构建说明：`../../docker/README.md`
