from __future__ import annotations

import calendar
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Sequence

from sqlalchemy.orm import Session, selectinload

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:  # pragma: no cover - optional dependency
    firebase_admin = None  # type: ignore[assignment]
    credentials = None  # type: ignore[assignment]
    messaging = None  # type: ignore[assignment]

from .. import models
from ..config import get_settings
from ..database import SessionLocal
from ..repositories.notification_repository import NotificationRepository
from ..schemas import notification as notification_schema
from ..schemas import task as task_schema

logger = logging.getLogger(__name__)


class NotificationService:
    def __init__(
        self,
        repository: NotificationRepository | None = None,
    ) -> None:
        self._repository = repository or NotificationRepository()
        self._settings = get_settings()
        self._firebase_ready = False
        self._firebase_failed = False

    # Device management -------------------------------------------------

    def register_device(
        self,
        db: Session,
        payload: notification_schema.DeviceRegistration,
    ) -> notification_schema.Device:
        if not payload.channels:
            payload.channels = [task_schema.NotificationChannel.push]
        device = self._repository.upsert_device(db, payload)
        return self._to_device_schema(device)

    def update_device(
        self,
        db: Session,
        *,
        user_id: str,
        device_token: str,
        update: notification_schema.DevicePreferenceUpdate,
    ) -> notification_schema.Device | None:
        device = self._repository.update_device(
            db,
            user_id=user_id,
            device_token=device_token,
            update=update,
        )
        if device is None:
            return None
        return self._to_device_schema(device)

    def list_devices(
        self,
        db: Session,
        *,
        user_id: str,
    ) -> notification_schema.DeviceCollection:
        items = [
            self._to_device_schema(device)
            for device in self._repository.list_devices(db, user_id=user_id)
        ]
        return notification_schema.DeviceCollection(items=items, total=len(items))

    def remove_device(self, db: Session, *, device_token: str) -> None:
        self._repository.remove_device(db, device_token=device_token)

    # Reminder dispatch -------------------------------------------------

    def run_due_reminders(self) -> int:
        session = SessionLocal()
        try:
            return self.dispatch_due_reminders(session)
        finally:
            session.close()

    def dispatch_due_reminders(
        self,
        db: Session,
        *,
        reference: datetime | None = None,
    ) -> int:
        now = reference.astimezone(timezone.utc) if reference else datetime.now(timezone.utc)
        window_minutes = max(self._settings.notification_batch_window_minutes, 1)
        upper_bound = now + timedelta(minutes=window_minutes)
        lookback = now - timedelta(minutes=window_minutes)

        reminders = (
            db.query(models.TaskReminder)
            .options(selectinload(models.TaskReminder.task))
            .join(models.Task)
            .filter(models.TaskReminder.active.is_(True))
            .filter(models.TaskReminder.remind_at <= upper_bound)
            .filter(models.TaskReminder.remind_at >= lookback)
            .filter(
                (models.TaskReminder.expires_at.is_(None))
                | (models.TaskReminder.expires_at >= now)
            )
            .filter(
                models.Task.status.in_(
                    (models.TaskStatus.pending, models.TaskStatus.in_progress)
                )
            )
            .order_by(models.TaskReminder.remind_at.asc())
            .all()
        )

        if not reminders:
            return 0

        grouped: dict[str, list[models.TaskReminder]] = {}
        for reminder in reminders:
            if (
                reminder.task is None
                or reminder.last_triggered_at is not None
                and reminder.last_triggered_at >= reminder.remind_at
            ):
                continue
            user_id = reminder.task.user_id
            if not user_id:
                continue
            grouped.setdefault(user_id, []).append(reminder)

        if not grouped:
            return 0

        devices = self._repository.active_devices_for_users(
            db, user_ids=grouped.keys()
        )
        device_map: dict[str, list[tuple[models.UserDevice, list[task_schema.NotificationChannel]]]] = {}
        for device in devices:
            channels = self._repository.deserialize_channels(device.channels)
            if not channels:
                continue
            if not device.device_token:
                continue
            device_map.setdefault(device.user_id, []).append((device, channels))

        dispatched = 0
        for user_id, user_reminders in grouped.items():
            contexts = device_map.get(user_id)
            if not contexts:
                continue
            for reminder in user_reminders:
                if self._dispatch_single_reminder(db, reminder, contexts, now):
                    dispatched += 1

        if dispatched:
            db.commit()

        return dispatched

    # Internal helpers --------------------------------------------------

    def _dispatch_single_reminder(
        self,
        db: Session,
        reminder: models.TaskReminder,
        contexts: Sequence[tuple[models.UserDevice, list[task_schema.NotificationChannel]]],
        now: datetime,
    ) -> bool:
        channel = reminder.channel or models.NotificationChannel.push

        if channel == models.NotificationChannel.email:
            logger.info(
                'Email dispatch requested for reminder %s (task %s); feature not implemented yet',
                reminder.id,
                reminder.task_id,
            )
            reminder.last_triggered_at = now
            reminder.active = False
            return True

        eligible_tokens: list[str] = []
        eligible_devices: list[models.UserDevice] = []

        for device, channels in contexts:
            if self._channel_supported(channel, channels):
                eligible_tokens.append(device.device_token)
                eligible_devices.append(device)

        if not eligible_tokens:
            logger.debug(
                'No eligible devices for reminder %s on channel %s',
                reminder.id,
                channel.value,
            )
            return False

        task = reminder.task
        if task is None:
            return False

        silent = channel == models.NotificationChannel.local

        success = self._send_push(  # returns True if at least one delivery attempt
            db,
            tokens=eligible_tokens,
            reminder=reminder,
            task=task,
            silent=silent,
        )

        if not success:
            return False

        reminder.last_triggered_at = now
        next_remind_at = self._next_remind_at(reminder)
        if next_remind_at is None:
            reminder.active = False
        else:
            reminder.remind_at = next_remind_at

        return True

    def _channel_supported(
        self,
        channel: models.NotificationChannel,
        channels: Sequence[task_schema.NotificationChannel],
    ) -> bool:
        if channel == models.NotificationChannel.push:
            return task_schema.NotificationChannel.push in channels
        if channel == models.NotificationChannel.local:
            return (
                task_schema.NotificationChannel.local in channels
                or task_schema.NotificationChannel.push in channels
            )
        if channel == models.NotificationChannel.email:
            # Email delivery is not implemented yet
            return False
        return False

    def _send_push(
        self,
        db: Session,
        *,
        tokens: Sequence[str],
        reminder: models.TaskReminder,
        task: models.Task,
        silent: bool,
    ) -> bool:
        messaging_client = self._ensure_messaging()
        if messaging_client is None:
            logger.debug('Push messaging unavailable; skipping dispatch')
            return False

        if not tokens:
            return False

        # Build message payload
        remind_at_iso = reminder.remind_at.astimezone(timezone.utc).isoformat()
        title = task.title or 'Task Reminder'
        body = self._build_notification_body(reminder)

        data_payload = {
            'type': 'task_reminder',
            'task_id': task.id,
            'reminder_id': str(reminder.id),
            'channel': reminder.channel.value if reminder.channel else 'push',
            'silent': 'true' if silent else 'false',
            'scheduled_at': remind_at_iso,
            'timezone': reminder.timezone or 'UTC',
            'repeat_rule': reminder.repeat_rule.value if reminder.repeat_rule else 'none',
            'repeat_every': str(reminder.repeat_every or 1),
            'title': title,
            'body': body,
        }

        notification_payload = None
        if not silent:
            notification_payload = messaging.Notification(title=title, body=body)

        total_sent = 0
        chunk_size = 500
        for index in range(0, len(tokens), chunk_size):
            batch = tokens[index : index + chunk_size]
            message = messaging.MulticastMessage(
                tokens=batch,
                notification=notification_payload,
                data=data_payload,
            )
            response = messaging_client.send_multicast(message, dry_run=False)
            total_sent += response.success_count

            if response.failure_count:
                for idx, result in enumerate(response.responses):
                    error = result.exception
                    if error is None:
                        continue
                    token = batch[idx]
                    logger.warning(
                        'Failed to deliver reminder %s to token %s: %s',
                        reminder.id,
                        token,
                        error,
                    )
                    if getattr(error, 'code', '') in {'registration-token-not-registered', 'invalid-argument'}:
                        self._repository.remove_device(db, device_token=token)

        return total_sent > 0

    def _build_notification_body(self, reminder: models.TaskReminder) -> str:
        try:
            from zoneinfo import ZoneInfo
        except ImportError:  # pragma: no cover - Python < 3.9
            ZoneInfo = None  # type: ignore[assignment]

        remind_at = reminder.remind_at
        if ZoneInfo is not None and reminder.timezone:
            try:
                tz = ZoneInfo(reminder.timezone)
            except Exception:
                tz = None
            if tz is not None:
                remind_at = remind_at.astimezone(tz)

        formatted = remind_at.strftime('%Y-%m-%d %H:%M')
        return f'提醒时间：{formatted}'

    def _next_remind_at(self, reminder: models.TaskReminder) -> datetime | None:
        if reminder.repeat_rule is None or reminder.repeat_rule == models.TaskReminderRepeat.none:
            return None

        interval = max(reminder.repeat_every or 1, 1)
        current = reminder.remind_at

        if reminder.repeat_rule == models.TaskReminderRepeat.daily:
            next_time = current + timedelta(days=interval)
        elif reminder.repeat_rule == models.TaskReminderRepeat.weekly:
            next_time = current + timedelta(weeks=interval)
        elif reminder.repeat_rule == models.TaskReminderRepeat.monthly:
            next_time = self._add_months(current, interval)
        else:
            return None

        if reminder.expires_at is not None and next_time > reminder.expires_at:
            return None

        return next_time

    def _add_months(self, dt: datetime, months: int) -> datetime:
        month = dt.month - 1 + months
        year = dt.year + month // 12
        month = month % 12 + 1
        day = min(dt.day, calendar.monthrange(year, month)[1])
        return dt.replace(year=year, month=month, day=day)

    def _ensure_messaging(self):
        if self._firebase_failed:
            return None
        if messaging is None or firebase_admin is None:
            logger.warning('firebase_admin is not installed; push notifications disabled')
            self._firebase_failed = True
            return None

        if self._firebase_ready:
            return messaging

        try:
            firebase_admin.get_app()
        except ValueError:
            cred_file = self._settings.firebase_credentials_file
            if cred_file:
                path = Path(cred_file)
                if not path.exists():
                    logger.error(
                        'Firebase credentials file %s not found; push disabled',
                        cred_file,
                    )
                    self._firebase_failed = True
                    return None
                cred = credentials.Certificate(str(path))
                firebase_admin.initialize_app(cred)
            else:
                firebase_admin.initialize_app()

        self._firebase_ready = True
        return messaging

    def _to_device_schema(
        self,
        device: models.UserDevice,
    ) -> notification_schema.Device:
        channels = self._repository.deserialize_channels(device.channels)
        try:
            platform = notification_schema.DevicePlatform(device.platform)
        except ValueError:
            platform = notification_schema.DevicePlatform.android
        return notification_schema.Device(
            id=device.id,
            device_token=device.device_token,
            platform=platform,
            channels=channels,
            locale=device.locale,
            timezone=device.timezone,
            app_version=device.app_version,
            is_active=bool(device.is_active),
            last_seen_at=device.last_seen_at,
            created_at=device.created_at,
            updated_at=device.updated_at,
        )
