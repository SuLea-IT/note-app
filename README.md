# Note App

This project contains:

- **frontend/** – Flutter application targeting Android that implements the note, habit, and diary experiences shown in the `/UI` mockups. The UI follows a modular structure with feature folders, shared styling, Provider-based state management, and remote data sources.
- **backend/** – FastAPI service exposing REST endpoints (/api/home/feed, /api/notes, /api/habits, /api/diaries) that serve the data consumed by the Flutter app.
  - Supports full diary management (GET/POST/PUT/DELETE /api/diaries) alongside the home feed pipeline.

> **Note**: All persistent data (notes, diaries, habits, quick actions, templates, etc.) must reside in the MySQL database. File-based JSON configuration has been removed in favour of relational tables.

## Backend (FastAPI)

1. Activate the provided Conda environment:
   ```bash
   conda activate lab-gene
   ```
2. Install dependencies (once):
   ```bash
   cd backend
   pip install -r requirements.txt
   ```
3. Run the API:
 ```bash
  uvicorn app.main:app --reload
  ```
  The service listens on `http://127.0.0.1:8000`. In Android emulators the same server is reachable via `http://10.0.2.2:8000`.
4. Authentication now issues JWT tokens. Configure the following environment values as needed (defaults are provided):
   - `AUTH_SECRET_KEY` – symmetric key for signing tokens.
   - `AUTH_ACCESS_TOKEN_EXPIRE_MINUTES` – access token lifetime (default 60 minutes).
   - `AUTH_REFRESH_TOKEN_EXPIRE_DAYS` – refresh token lifetime (default 14 days).
   - `SHARE_BASE_URL` – public base URL used when minting diary share links (default `https://note-app.example.com/share`).
   - Use `POST /api/auth/refresh` with a refresh token to obtain a new access token.
5. Home quick actions are now stored in MySQL (`quick_actions` + `quick_action_translations`). Seed data via SQL migrations or scripts，例如：
   ```sql
   INSERT INTO quick_actions (id, icon, order_index, background_color, foreground_color, default_title, default_subtitle, default_locale)
   VALUES ('action-diary', 'diary', 10, 0xFFFFF1E6, 0xFFFF8B3D, 'Diary', 'Capture today''s reflections', 'en');

   INSERT INTO quick_action_translations (action_id, locale, title, subtitle)
   VALUES ('action-diary', 'zh-CN', '写日记', '记录当下灵感');
   ```
6. Notes API enhancements：
   - 新增 `note_attachments`、`note_tags`、`note_tag_links` 三张表，支持笔记附件与标签的持久化。
   - `POST /api/notes`、`PUT /api/notes/{id}` 接收 `attachments`、`tags` 字段；`GET /api/notes/feed`、`/api/home/feed` 返回标签集合。
   - `GET /api/notes/search?q=关键字` 支持标题/内容/标签模糊检索。
7. Habits API enhancements：
   - `habits` 表新增提醒时间 `reminder_time`、重复规则 `repeat_rule` 与主题色 `accent_color` 字段。
   - 新增 `habit_entries` 历史表，`/habits/feed` 返回实际打卡时间线、连续天数、活跃天数与历史记录。
   - `PUT /api/habits/{id}` 在状态切换时会自动写入/撤销当日打卡记录并返回最新统计。
8. Tasks API：
   - 新建 `tasks`、`task_tags`、`task_tag_links`、`task_reminders` 表，支持标签、多提醒、优先级以及与笔记/日记的关联。
   - `GET /api/tasks` 提供过滤、分页、搜索；`POST /api/tasks/bulk-complete` 实现批量完成；`GET /api/tasks/stats` 返回统计数据。
   - Home Feed (`/api/home/feed`) 现返回任务统计卡片，便于前端展示今日/逾期/本周任务概览。
9. Audio Notes：
   - 新增 `audio_notes` 表与 `/api/audio-notes` CRUD/搜索接口，字段覆盖音频 URL、时长、文件信息与转写状态。
   - `PATCH /api/audio-notes/{id}/transcription` 支持队列回调写入转写文本/语言/错误信息，前端可轮询状态。
10. Personal Center：
   - `users` 表扩展头像、主题、最后活跃时间；登录与刷新令牌时自动刷新活跃时间。
   - 新增 `/api/users/me` 返回用户资料与统计（笔记数、日记数、习惯数、连胜天数、最近活跃时间）。
11. Global Search：
   - `/api/search` 聚合笔记、日记、任务、习惯、语音笔记，支持类型筛选、日期区间与分页限制。
   - 结果按类型分组返回，同时提供统一列表（按时间倒序）以及关键字段摘要，便于前端展示。

## Flutter Frontend

1. Fetch dependencies:
   ```bash
   cd frontend
   flutter pub get
   ```
2. (Optional) Point the app at a custom API endpoint:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
   ```
   Without `--dart-define` the app defaults to `http://10.0.2.2:8000/api` which works for Android emulators.
3. Run tests (they execute against local mock repositories):
   ```bash
   flutter test
   ```

The app automatically requests remote data when available. If you need to fall back to offline mocks (for example in tests), instantiate `NoteApp(useRemote: false)`.

## Structure Highlights

- `lib/core/` – shared theme, configuration, and HTTP client.
- `lib/features/home|habits|diary/` – feature-specific domain models, data repositories, controllers, and presentation widgets.
- Remote repositories map the FastAPI JSON payloads into strongly-typed domain entities, while mock repositories provide design-time data.

## Next Steps

- Persist quick-action tiles (served via /api/home/feed) so they can be managed without code changes.
- Connect the repositories to a persistent database (use the `.env` credentials) or ORM layer.
- Expand network error handling/UI states as endpoints evolve.

## Notifications

### Backend

- APScheduler �Զ������� FastAPI Ӧ��ʱ��������Ҫ������ʱ���ػ�������ȷ�������ֶκ͵��õȡ�
- �½� `/api/notifications` ģ������� `POST/GET/PATCH/DELETE /devices` �� `POST /dispatch` �ӿڣ������豸 Token ע��͸��£�Ȩ��֪ͨ��������
- ���� `user_devices` �����Լ� `task_reminders` �ֶΣ�Ҫͨ�� alembic �������ֶ���չ�������� SQL �������ɵ����Զ���롣
- `.env` �������Ӷ��������ã�`FIREBASE_CREDENTIALS_FILE`��`NOTIFICATION_DEFAULT_TIMEZONE`��`NOTIFICATION_POLL_INTERVAL_SECONDS`��`NOTIFICATION_BATCH_WINDOW_MINUTES` �Լ��廯��Ϣ��

### Frontend

- Flutter �߻��뾭���� Firebase Core/Firebase Messaging/Flutter Local Notifications/permission_handler/flutter_native_timezone/timezone �ȿ̳̣�ִ�� `flutter pub get` �������½���������
- ���� Firebase ��Ŀ���������ṩ `google-services.json`/`GoogleService-Info.plist` �� `lib/firebase_options.dart`��ȷ����ע FCM Token ��Ϣ�Լ��豸Ȩ�ޡ�
- `NotificationController` �Զ���ʼ����ע�豸FCM Token��ǿ֧��������ӳ�ֵ����ʱ�޸ĵ�������ʽ�������ص������б��ں�Ա��¼��
C:\ProgramData\Anaconda3\envs\note-app\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0
C:\ProgramData\Anaconda3\envs\note-app\python.exe scripts\start_all.py --emulator-id Pixel_5_API_34 --api-base-url http://192.168.128.203:8000/api
