from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class TaskPriority(str, Enum):
    low = 'low'
    normal = 'normal'
    high = 'high'
    urgent = 'urgent'


class TaskStatus(str, Enum):
    pending = 'pending'
    in_progress = 'in_progress'
    completed = 'completed'
    cancelled = 'cancelled'


class TaskAssociationType(str, Enum):
    note = 'note'
    diary = 'diary'


class NotificationChannel(str, Enum):
    push = 'push'
    local = 'local'
    email = 'email'


class ReminderRepeatRule(str, Enum):
    none = 'none'
    daily = 'daily'
    weekly = 'weekly'
    monthly = 'monthly'


class TaskReminderPayload(BaseModel):
    remind_at: datetime
    timezone: str = Field(default='UTC', min_length=1, max_length=64)
    channel: NotificationChannel = NotificationChannel.push
    repeat_rule: ReminderRepeatRule = ReminderRepeatRule.none
    repeat_every: int = Field(default=1, ge=1, le=365)
    active: bool = True
    expires_at: datetime | None = None


class TaskReminderUpsert(TaskReminderPayload):
    id: int | None = Field(default=None, ge=1)


class TaskReminder(TaskReminderPayload):
    id: int
    created_at: datetime
    updated_at: datetime | None = None
    last_triggered_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class TaskBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    due_at: datetime | None = None
    all_day: bool = False
    priority: TaskPriority = TaskPriority.normal
    status: TaskStatus = TaskStatus.pending
    order_index: int | None = None
    related_entity_id: str | None = Field(default=None, max_length=255)
    related_entity_type: TaskAssociationType | None = None


class TaskCreate(TaskBase):
    user_id: str = Field(..., min_length=1, max_length=255)
    tags: list[str] | None = None
    reminders: list[TaskReminderUpsert] | None = None


class TaskUpdate(TaskBase):
    tags: list[str] | None = None
    reminders: list[TaskReminderUpsert] | None = None


class Task(TaskBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime | None = None
    completed_at: datetime | None = None
    tags: list[str] = Field(default_factory=list)
    reminders: list[TaskReminder] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class TaskSummary(BaseModel):
    id: str
    title: str
    status: TaskStatus
    due_at: datetime | None = None
    priority: TaskPriority
    tags: list[str] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class TaskCollection(BaseModel):
    total: int
    items: list[Task]


class TaskBulkCompletionRequest(BaseModel):
    task_ids: list[str] = Field(..., min_length=1)
    completed: bool = True


class TaskStatistics(BaseModel):
    pending_today: int
    overdue: int
    upcoming_week: int
    completed_today: int
