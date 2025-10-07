from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field

from .task import NotificationChannel


class DevicePlatform(str, Enum):
    android = 'android'
    ios = 'ios'
    web = 'web'


class DeviceRegistration(BaseModel):
    user_id: str = Field(..., min_length=1, max_length=255)
    device_token: str = Field(..., min_length=1, max_length=1024)
    platform: DevicePlatform
    channels: list[NotificationChannel] = Field(
        default_factory=lambda: [NotificationChannel.push],
    )
    locale: str | None = Field(default=None, max_length=32)
    timezone: str = Field(default='UTC', min_length=1, max_length=64)
    app_version: str | None = Field(default=None, max_length=32)
    push_enabled: bool = True


class DevicePreferenceUpdate(BaseModel):
    channels: list[NotificationChannel] | None = None
    push_enabled: bool | None = None
    locale: str | None = Field(default=None, max_length=32)
    timezone: str | None = Field(default=None, max_length=64)
    app_version: str | None = Field(default=None, max_length=32)


class Device(BaseModel):
    id: int
    device_token: str
    platform: DevicePlatform
    channels: list[NotificationChannel]
    locale: str | None
    timezone: str
    app_version: str | None
    is_active: bool
    last_seen_at: datetime | None = None
    created_at: datetime
    updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class DeviceCollection(BaseModel):
    items: list[Device]
    total: int

