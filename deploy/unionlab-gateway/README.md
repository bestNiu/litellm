# UnionLab Gateway 部署指南

本目录包含 UnionLab Gateway（基于 unionlabLLM，上游为 [LiteLLM](https://github.com/BerriAI/litellm)）的 Docker Compose 部署配置，使用外部 PostgreSQL（阿里云 RDS），不启动本地数据库容器。

这是 LiteLLM 的二次开发部署。UnionLab 品牌页、管理后台静态资源与 Proxy 进程不在同一层，**日常不要用 `docker compose restart`**：它只重启进程，不会重建容器，也不会重新挂载二开 UI。

## 目录结构

```
deploy/unionlab-gateway/
├── README.md                  # 本文档
├── docker-compose.build.yml   # 从源码构建并部署（推荐用于二次开发）
├── docker-compose.yml         # 使用官方预构建镜像快速部署
├── config.yaml                # unionlabLLM Proxy 业务配置
├── .env.example               # 环境变量模板（可提交 Git）
├── .env                       # 实际环境变量（含密钥，勿提交）
├── .gitignore                 # 忽略 .env 与 custom-ui/
├── ensure-ui.sh               # 校验 / 同步 custom-ui（不跑 npm）
├── reload.sh                  # 校验 UI 后 up -d 重建容器（推荐）
├── build-ui.sh                # 从源码构建 UI 并同步到 custom-ui/
└── custom-ui/                 # UI 构建产物（勿提交，由 build-ui.sh / ensure-ui.sh 生成）
```

源码仓库根目录为 `app/`（即本目录的上两级 `../..`），构建时会从该路径读取 Dockerfile 与完整代码。

---

## 二开 UI 是怎么挂上的

二次开发后有 **三层界面**，改动后要用不同的命令才会生效：

| 层级 | 访问地址 | 来源 | `restart` 能否更新 |
|------|----------|------|-------------------|
| 根路径品牌页 | `/` | Python 代码，打进镜像（`proxy_server.py` 的 `home()`） | 否，需要 `--build` |
| 管理后台（UnionLab Admin UI） | `/ui` | 宿主机 `custom-ui/` 挂载到容器 `/var/lib/litellm/ui` | 否，需要 `up -d` 重建容器 |
| 镜像内兜底 UI | `/ui`（仅 custom-ui 为空时） | 镜像 site-packages 里的 packaged UI | 否，需要 `--build` |

运行时优先级：

1. `LITELLM_UI_PATH=/var/lib/litellm/ui`（bind mount 的 `./custom-ui`）
2. 若该目录为空或不完整，LiteLLM 回退到镜像内 packaged UI
3. 根路径 `/` 始终走镜像里的 Python，与 `custom-ui` 无关

`custom-ui/` 已在 `.gitignore` 中。新机器 `git clone` 后这个目录不存在，Docker 会创建一个空目录并挂上去。空目录不会覆盖镜像 UI（因为挂载点与 packaged UI 不是同一路径），但官方预构建镜像没有 UnionLab 品牌，看起来会像「二开 UI 丢了」。因此启动前必须先跑 `./ensure-ui.sh` 或 `./build-ui.sh`。

**不要把 `custom-ui` 挂到 `/app/litellm/proxy/_experimental/out`。** 源码构建镜像里真正的 packaged UI 在 site-packages，那个路径只是空挂载点；挂错后一旦 `custom-ui` 为空，管理后台会 404。

---

## 改什么，用什么命令

请优先使用 `./reload.sh`。它会先校验 `custom-ui`，再执行 `docker compose up -d` 重建容器。

| 你改了什么 | 正确命令 | 错误做法 |
|------------|----------|----------|
| `config.yaml` | `./reload.sh` | `docker compose restart`（多数情况能读到文件，但不保证 compose/env 一并生效） |
| `.env` / compose 的 `environment` | `./reload.sh` | `restart` **不会**重新加载环境变量 |
| `custom-ui/` 或刚跑完 `./build-ui.sh` | `./reload.sh` | `restart` **不会**按新的 volume 定义重建容器 |
| `ui/litellm-dashboard/` 源码 | `./build-ui.sh && ./reload.sh` | 只 restart；或只 `--build` 但没同步 custom-ui |
| Python / 根路径品牌页 / Dockerfile | `./reload.sh --build` | `restart` 用的还是旧镜像 |
| `git pull` 后既有代码又有 UI | `./build-ui.sh && ./reload.sh --build` | 只 `git pull` + `restart` |

`docker compose restart` 只 SIGTERM/再启动同一容器：volume、镜像、`.env` 都保持创建时的状态。compose 里后来才加上的 `custom-ui` 挂载，restart 之后仍然不会出现。

---

## 前置条件

- Docker Engine 与 Docker Compose v2
- Node.js 20（推荐通过 nvm 安装，用于 UI 构建）
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

`litellm_settings.ui_theme_config.hide_upstream_ui_extras: true` 可隐藏顶部 **Docs / Blog / Slack / GitHub** 链接、右上角 **通知铃铛**、Logo 旁的 **版本号标识（v1.x.x）**，以及用户菜单中的 **Hide New Feature Indicators** 等偏好开关（UnionLab 默认已开启）。

`docker-compose*.yml` 中已设置 `NO_DOCS`、`NO_REDOC`、`NO_OPENAPI` 为 `True`，关闭对外暴露的 API 文档页面（Swagger `/`、ReDoc `/redoc`、OpenAPI `/openapi.json`），避免公网直接访问。这三项必须作为容器环境变量设置（FastAPI 在加载 `config.yaml` 之前就已读取），不能写在 `config.yaml` 的 `environment_variables` 中。关闭 Swagger 后，根路径 `/` 由二次开发的 UnionLab 品牌页接管。

### 3. 准备二开 UI

```bash
chmod +x ensure-ui.sh reload.sh build-ui.sh
./ensure-ui.sh
```

`ensure-ui.sh` 会检查 `custom-ui/index.html` 与 `custom-ui/_next/`。若缺失，则从仓库里已有的 `litellm/proxy/_experimental/out` 同步一份。两边都没有时，再跑 `./build-ui.sh`（需要 Node.js 20）。

### 4. 选择部署方式并启动

**方式 A：从源码构建（推荐，含最新 Python 代码、根路径品牌页与 UI 二次开发）**

```bash
./reload.sh --build
```

**方式 B：使用官方预构建镜像（启动快，版本固定为 v1.89.2，不含根路径品牌页）**

```bash
./ensure-ui.sh
COMPOSE_FILE=docker-compose.yml ./reload.sh
```

> 两种方式共用容器名 `unionlab-gateway`，不可同时运行。

### 5. 验证

```bash
# 查看容器状态
docker compose -f docker-compose.build.yml ps

# 健康检查
curl -sS http://127.0.0.1:4000/health/liveliness

# 根路径应为 UnionLab 品牌页，而不是 LiteLLM: RUNNING
curl -sS http://127.0.0.1:4000/ | grep -o "UnionLab AI Gateway"

# 管理后台应为 unionlabLLM，而不是上游 LiteLLM Admin UI
curl -sS http://127.0.0.1:4000/ui/ | grep -o "unionlabLLM"

# 确认 custom-ui 已挂到独立 UI 路径
docker inspect unionlab-gateway --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'

# 日志中应出现 Using pre-restructured UI at /var/lib/litellm/ui
docker compose -f docker-compose.build.yml logs unionlab-gateway | grep -E "UI at |Using packaged UI"
```

- 根路径品牌页：`http://<服务器IP>:4000/`
- 管理 UI：`http://<服务器IP>:4000/ui`
- API 端口：`4000`（`network_mode: host`，直接监听宿主机）

若根路径返回 `LiteLLM: RUNNING`，说明当前容器跑的还是旧镜像，执行 `./reload.sh --build`。若 `/ui` 没有 `unionlabLLM` 字样，说明 `custom-ui` 没挂上或为空，执行 `./ensure-ui.sh && ./reload.sh`。

---

## 日常运维

```bash
cd /root/app/litellm/app/deploy/unionlab-gateway

# 修改 config.yaml / .env / custom-ui 后：重建容器（推荐）
./reload.sh

# 拉取最新代码后重新构建镜像并部署
cd ../.. && git pull && cd deploy/unionlab-gateway
./build-ui.sh          # UI 源码有变时
./reload.sh --build    # Python / Dockerfile / 品牌页有变时

# 停止服务
docker compose -f docker-compose.build.yml down

# 完全重建镜像（不使用缓存）
docker compose -f docker-compose.build.yml build --no-cache
./reload.sh
```

---

## UI 二次开发

UI 源码位于仓库 `ui/litellm-dashboard/`，品牌配置集中在 `ui/litellm-dashboard/src/lib/unionlabBrand.ts`。

### 安装 Node.js（首次）

```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
```

### 构建并部署 UI

```bash
cd /root/app/litellm/app/deploy/unionlab-gateway
./build-ui.sh
./reload.sh
```

`build-ui.sh` 会执行 `npm install && npm run build`，写入 `.litellm_ui_ready` 标记，并将产物同步到：

- `deploy/unionlab-gateway/custom-ui/`（运行时挂载目录）
- `litellm/proxy/_experimental/out/`（下次构建 Docker 镜像时打进 packaged UI）

只改 UI、不改 Python 时，**不必** `--build`。只改 Python / 根路径品牌页、不改 UI 时，**不必**再跑 `build-ui.sh`。

### 自定义 UI 挂载

源码构建与预构建镜像两种 compose 都使用同一套独立路径：

```yaml
volumes:
  - ./config.yaml:/app/config.yaml:ro
  - ./custom-ui:/var/lib/litellm/ui:ro
environment:
  LITELLM_UI_PATH: /var/lib/litellm/ui
```

挂载为只读。LiteLLM 启动时若发现 `.litellm_ui_ready` 或已有 `login/index.html` 这类目录结构，会跳过原地改写静态文件。`build-ui.sh` / `ensure-ui.sh` 都会写入该标记。

---

## Git 管理说明

| 文件/目录 | 是否提交 Git | 说明 |
|-----------|-------------|------|
| `config.yaml` | ✅ | 业务配置 |
| `docker-compose*.yml` | ✅ | 部署编排 |
| `build-ui.sh` / `ensure-ui.sh` / `reload.sh` | ✅ | UI 构建与容器重建 |
| `.env.example` | ✅ | 环境变量模板 |
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
3. 镜像会把 `litellm/proxy/_experimental/out` 打进 site-packages 作为兜底 UI；运行时以 `custom-ui` 挂载为准。
4. 上游 `docker/build_admin_ui.sh` 依赖 `enterprise/enterprise_ui/enterprise_colors.json`，本仓库默认没有该文件，Docker 构建**不会**重新编译 Admin UI。UnionLab UI 靠 `./build-ui.sh` 或仓库内已有的 `_experimental/out` 提供。

### 升级

1. **源码构建模式**：`git pull` 后按需 `./build-ui.sh`，再 `./reload.sh --build`。
2. **预构建镜像模式**：修改 `docker-compose.yml` 中的 `image` 版本号后 `docker compose pull && COMPOSE_FILE=docker-compose.yml ./reload.sh`。升级官方镜像会丢掉根路径品牌页，除非继续挂载 `custom-ui`。
3. 升级前建议备份 RDS 数据库。

### 故障排查

| 现象 | 可能原因 | 处理 |
|------|---------|------|
| 容器反复重启 | RDS 不可达或密码错误 | 检查 `.env` 与 RDS 白名单，`docker compose logs` 查看报错 |
| `Master key is not initialized` | 未配置 `.env` 或未加载 | 确认 `.env` 存在且含 `LITELLM_MASTER_KEY`；改 `.env` 后用 `./reload.sh` 而不是 restart |
| `/` 显示 `LiteLLM: RUNNING` | 旧镜像，restart 没有带上品牌页代码 | `./reload.sh --build` |
| `/ui` 404 或变回上游 LiteLLM UI | `custom-ui` 未挂载、为空，或只用了 restart | `./ensure-ui.sh && ./reload.sh`，再用 `docker inspect` 确认挂载到 `/var/lib/litellm/ui` |
| 日志 `Failed to populate UI` / `Falling back to packaged UI` | 挂载目录为空且只读 | 先 `./ensure-ui.sh`，再 `./reload.sh` |
| 日志 `Cannot restructure UI` | 挂载为只读且缺少 `.litellm_ui_ready` | 跑 `./ensure-ui.sh` 写入标记后 `./reload.sh` |
| 构建失败 | 网络问题或磁盘不足 | 检查 Docker 日志，`df -h` 确认磁盘空间 |

---

## 相关链接

- unionlabLLM 官方文档（上游）：https://docs.litellm.ai/
- 源码 UI 目录：`../../ui/litellm-dashboard/`
- Docker 构建说明：`../../docker/README.md`
