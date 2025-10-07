from __future__ import annotations

from datetime import date, datetime, time
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class HabitStatus(str, Enum):
    upcoming = 'upcoming'
    in_progress = 'in_progress'
    completed = 'completed'


class HabitDay(BaseModel):
    date: date
    is_today: bool
    completed_count: int
    total_count: int
    completion_rate: float | None = None


class HabitTranslationPayload(BaseModel):
    locale: str = Field(..., min_length=2, max_length=32)
    title: str
    description: str | None = None
    time_label: str | None = None


class HabitBase(BaseModel):
    title: str
    description: str | None = None
    time_label: str | None = None
    status: HabitStatus = HabitStatus.upcoming
    reminder_time: time | None = None
    repeat_rule: str | None = None
    accent_color: int | None = Field(default=None, ge=0)


class HabitSummary(HabitBase):
    id: str
    user_id: str
    streak_days: int = 0
    completed_today: bool = False


class HabitOverview(BaseModel):
    focus_minutes: int
    completed_streak: int
    total_habits: int
    completion_rate: float = 0.0
    active_days: int = 0


class HabitHistoryEntry(BaseModel):
    habit_id: str
    title: str
    date: date
    status: HabitStatus
    completed_at: datetime | None = None
    duration_minutes: int | None = None


class HabitFeed(BaseModel):
    days: list[HabitDay]
    entries: list[HabitSummary]
    overview: HabitOverview
    history: list[HabitHistoryEntry] = Field(default_factory=list)


class HabitCreate(HabitBase):
    user_id: str
    default_locale: str = Field(default='en-US', min_length=2, max_length=32)
    translations: list[HabitTranslationPayload] | None = None


class HabitUpdate(HabitBase):
    default_locale: str | None = Field(default=None, min_length=2, max_length=32)
    translations: list[HabitTranslationPayload] | None = None


class HabitTranslation(HabitTranslationPayload):
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class Habit(HabitBase):
    id: str
    user_id: str
    default_locale: str
    created_at: datetime
    updated_at: datetime | None = None
    translations: list[HabitTranslation] = Field(default_factory=list)
    streak_days: int = 0
    completed_today: bool = False
    latest_entry: HabitHistoryEntry | None = None

    model_config = ConfigDict(from_attributes=True)
