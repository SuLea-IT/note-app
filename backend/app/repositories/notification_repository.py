from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Iterable

from sqlalchemy.orm import Session

from .. import models
from ..schemas import notification as notification_schema
from ..schemas import task as task_schema


class NotificationRepository:
    def upsert_device(
        self,
        db: Session,
        payload: notification_schema.DeviceRegistration,
    ) -> models.UserDevice:
        normalized_timezone = (payload.timezone or 'UTC').strip() or 'UTC'
        channels = self._serialize_channels(payload.channels)
        now = datetime.now(timezone.utc)

        device = (
            db.query(models.UserDevice)
            .filter(models.UserDevice.device_token == payload.device_token)
            .first()
        )

        if device is None:
            device = models.UserDevice(
                user_id=payload.user_id,
                device_token=payload.device_token,
                platform=payload.platform.value,
                channels=channels,
                locale=payload.locale,
                timezone=normalized_timezone,
                app_version=payload.app_version,
                is_active=payload.push_enabled,
                last_seen_at=now,
            )
            db.add(device)
        else:
            device.user_id = payload.user_id
            device.platform = payload.platform.value
            device.channels = channels
            device.locale = payload.locale
            device.timezone = normalized_timezone
            device.app_version = payload.app_version
            device.is_active = payload.push_enabled
            device.last_seen_at = now

        db.commit()
        db.refresh(device)
        return device

    def update_device(
        self,
        db: Session,
        *,
        user_id: str,
        device_token: str,
        update: notification_schema.DevicePreferenceUpdate,
    ) -> models.UserDevice | None:
        device = (
            db.query(models.UserDevice)
            .filter(models.UserDevice.user_id == user_id)
            .filter(models.UserDevice.device_token == device_token)
            .first()
        )
        if device is None:
            return None

        if update.channels is not None:
            device.channels = self._serialize_channels(update.channels)
        if update.push_enabled is not None:
            device.is_active = update.push_enabled
        if update.locale is not None:
            device.locale = update.locale
        if update.timezone is not None and update.timezone.strip():
            device.timezone = update.timezone.strip()
        if update.app_version is not None:
            device.app_version = update.app_version
        device.last_seen_at = datetime.now(timezone.utc)

        db.add(device)
        db.commit()
        db.refresh(device)
        return device

    def list_devices(self, db: Session, *, user_id: str) -> list[models.UserDevice]:
        return (
            db.query(models.UserDevice)
            .filter(models.UserDevice.user_id == user_id)
            .order_by(models.UserDevice.created_at.desc())
            .all()
        )

    def remove_device(self, db: Session, *, device_token: str) -> None:
        device = (
            db.query(models.UserDevice)
            .filter(models.UserDevice.device_token == device_token)
            .first()
        )
        if device is None:
            return
        db.delete(device)
        db.commit()

    def active_devices_for_users(
        self,
        db: Session,
        *,
        user_ids: Iterable[str],
    ) -> list[models.UserDevice]:
        user_ids = tuple({user_id for user_id in user_ids if user_id})
        if not user_ids:
            return []
        return (
            db.query(models.UserDevice)
            .filter(models.UserDevice.user_id.in_(user_ids))
            .filter(models.UserDevice.is_active.is_(True))
            .all()
        )

    def deserialize_channels(self, raw: str) -> list[task_schema.NotificationChannel]:
        if not raw:
            return [task_schema.NotificationChannel.push]
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            items = [value.strip() for value in raw.split(',') if value.strip()]
        else:
            items = [str(value).strip() for value in data if str(value).strip()]

        channels: list[task_schema.NotificationChannel] = []
        for value in items:
            try:
                channels.append(task_schema.NotificationChannel(value))
            except ValueError:
                continue
        return channels or [task_schema.NotificationChannel.push]

    def _serialize_channels(
        self, channels: Iterable[task_schema.NotificationChannel]
    ) -> str:
        unique = sorted({channel.value for channel in channels if channel is not None})
        if not unique:
            unique = [task_schema.NotificationChannel.push.value]
        return json.dumps(unique)

