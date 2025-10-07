# Note App · Flutter + FastAPI 全栈笔记应用

重新设计的 Note App 同时包含一个 Flutter 客户端与 FastAPI 后端，用于管理笔记、日记、习惯和任务。项目强调模块化架构、Provider 状态管理、RESTful API 与 MySQL 持久化，并提供自动化脚本帮助在本地快速启动完整环境。

## 功能概览 Highlights

- 📓 **笔记与日记**：支持标签、附件、全文搜索与模版管理。
- ✅ **任务看板**：丰富的筛选、分组与统计卡片，批量完成与提醒。
- 🔁 **习惯追踪**：打卡历史、提醒规则与醒目配色配置。
- 🔔 **通知中心**：APScheduler 定时调度、FCM 推送、跨端 Token 管理。
- 🔍 **全局检索**：聚合查询笔记/日记/习惯/任务，按类型统一展示。

## 项目结构 Project Layout

```
backend/    FastAPI 应用、SQLAlchemy/Alembic 数据层、业务服务与路由
frontend/   Flutter 3 应用，按 Feature 模块划分领域/数据/UI
scripts/    开发辅助脚本（如同时启动前后端的 start_all.py）
UI/         产品原型与参考视觉稿
```

## 环境要求 Prerequisites

- Python 3.11+ 与 pip / Conda
- MySQL 8.x（默认数据库名 `note_app`）
- Flutter 3.19+（Dart SDK ≥ 3.9.2）与 Android Studio / Xcode
- 可选：Firebase 项目（通知功能）

## 快速开始 Quick Start

### 1. 克隆仓库 Clone the repository

```bash
git clone https://github.com/SuLea-IT/note-app.git
cd note-app
```

### 2. 配置环境变量 Configure `.env`

在项目根目录创建 `.env`（后端自动加载）并填写数据库/认证/通知配置：

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=note_app
DB_USER=root
DB_PASSWORD=your_password

AUTH_SECRET_KEY=please-change-me
AUTH_ACCESS_TOKEN_EXPIRE_MINUTES=60
AUTH_REFRESH_TOKEN_EXPIRE_DAYS=14

SHARE_BASE_URL=https://note-app.example.com/share
FIREBASE_CREDENTIALS_FILE=path/to/firebase.json  # 如无需通知可留空
NOTIFICATION_DEFAULT_TIMEZONE=Asia/Shanghai
NOTIFICATION_POLL_INTERVAL_SECONDS=60
NOTIFICATION_BATCH_WINDOW_MINUTES=5
```

### 3. 准备数据库 Prepare the database

```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS note_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
cd backend
pip install -r requirements.txt
alembic upgrade head
```

### 4. 启动后端 Run the FastAPI backend

```bash
# 可选：使用 Conda 或 venv 创建隔离环境
conda create -n note-app python=3.11
conda activate note-app

cd backend
pip install -r requirements.txt
C:\ProgramData\Anaconda3\envs\note-app\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0

默认 API 入口为 `http://127.0.0.1:8000/api`，Android 模拟器可通过 `http://10.0.2.2:8000/api` 访问。

### 5. 启动前端 Run the Flutter app

```bash
cd frontend
flutter pub get
C:\ProgramData\Anaconda3\envs\note-app\python.exe scripts\start_all.py --emulator-id Pixel_5_API_34 --api-base-url http://192.168.128.203:8000/api```
```

如需 Web/Desktop 运行，可适配对应设备并传入合适的 API 地址。

### 6. 一键启动脚本 Helper script

使用根目录脚本自动管理 Emulator、后端与前端：

```bash
python scripts/start_all.py \
  --emulator-id Pixel_5_API_34 \
  --api-base-url http://10.0.2.2:8000/api
```

常用参数：

- `--skip-backend` / `--skip-frontend`：按需跳过某一端。
- `--backend-cmd` / `--frontend-cmd`：覆盖默认启动命令。
- `--require-android-device`：等待真实/虚拟 Android 设备接入。

## 目录说明 Codebase Notes

### 后端 Backend

- `app/config.py`：集中管理环境变量，并生成 `mysql+pymysql` 连接串。
- `app/routes/`：REST API（认证、笔记、日记、任务、习惯、通知等）。
- `app/services/`：业务逻辑层，封装聚合查询/统计/推送调度。
- `alembic/versions/`：数据库迁移脚本，覆盖任务提醒、音频笔记等增量表。
- `app/scheduler.py`：基于 APScheduler 的后台定时任务（推送轮询等）。

### 前端 Frontend

- `lib/core/`：主题配色、间距、网络客户端、本地化工具等。
- `lib/features/**`：按领域划分的数据层（Repository）、状态控制器（Controller）与 UI（Screen/Widget）。
- `lib/features/tasks/presentation/task_board_screen.dart`：任务看板页面，支持搜索、筛选与批量操作。
- `pubspec.yaml`：Dart/Flutter 版本约束与依赖（Provider、Intl、Flutter Local Notifications 等）。

## 本地开发指引 Development Tips

- 使用 `alembic revision --autogenerate -m "message"` 维护数据库结构变更。
- 后端调试推荐 `uvicorn app.main:app --reload --port 8000`，并结合 Swagger UI (`/docs`) 验证接口。
- 前端保持 `flutter analyze`、`flutter test` 通过，必要时运行 `dart format .` 统一格式。
- 多语言使用 `context.tr('中文', 'English')` 与 `trStatic` 辅助函数，新增文案请同时提供中英翻译。
- 推送功能需在 Firebase 控制台生成 `google-services.json` / `GoogleService-Info.plist` 并放置于对应平台目录。

## 测试与质量保证 Testing

- **Backend**：可使用 `pytest`（按需新增测试）结合 `httpx` 或 `fastapi.testclient` 做 API 覆盖。
- **Frontend**：运行 `flutter test` 与 `flutter analyze`，为新增 Widget/Controller 编写单元或集成测试。
- **Lint**：建议引入 `ruff`/`flake8`（Python）与 `dart analyze` 保持一致风格。

## 部署建议 Deployment Notes

- 生产环境建议通过 `uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4` 或 Gunicorn + UvicornWorker 部署。
- 数据库连接请启用 SSL，并将 `AUTH_SECRET_KEY` 等敏感变量通过环境变量注入。
- 前端可使用 `flutter build apk` / `flutter build appbundle` / `flutter build web` 输出正式版本。
- 定时任务依赖 APScheduler 内存调度，生产中可部署到独立进程或采用 Celery/云函数增强可靠性。

## 常见问题 FAQ

| 问题 | 解决方案 |
| ---- | -------- |
| Android 模拟器无法访问后端 | 确认使用 `http://10.0.2.2:8000` 并在防火墙中放行端口。 |
| 数据库连接失败 | 检查 `.env`、MySQL 权限与编码设置；确认 `alembic upgrade head` 已执行。 |
| 通知收不到 | 检查 Firebase 凭证、APScheduler 是否运行、前端是否授权通知。 |
| Flutter 编译缓慢 | 预热 Gradle，使用 `flutter precache`，关闭不必要的模拟器实例。 |

## 贡献 Contribution

欢迎提交 Issue 或 Pull Request：

1. Fork 仓库并创建新分支。
2. 修改代码并补充必要的测试/文档。
3. 保持 `flutter analyze`、`flutter test` 与后端代码检查通过。
4. 提交 PR 时说明变更动机与验证方式。

---

如需更多支持，欢迎在仓库 Issue 区反馈。Happy hacking! 🚀
