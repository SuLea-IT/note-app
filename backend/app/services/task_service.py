from __future__ import annotations

from datetime import datetime, timezone
from typing import Iterable

from sqlalchemy.orm import Session

from .. import models
from ..repositories.task_repository import TaskRepository
from ..schemas import task as task_schema


class TaskService:
    def __init__(self, repository: TaskRepository | None = None) -> None:
        self._repository = repository or TaskRepository()

    def get_task_model(self, db: Session, task_id: str) -> models.Task | None:
        return self._repository.get(db, task_id)

    def get_task(self, db: Session, task_id: str) -> task_schema.Task | None:
        record = self._repository.get(db, task_id)
        if record is None:
            return None
        return self._to_task(record)

    def list_tasks(
        self,
        db: Session,
        *,
        user_id: str,
        statuses: Iterable[task_schema.TaskStatus] | None = None,
        priorities: Iterable[task_schema.TaskPriority] | None = None,
        tags: Iterable[str] | None = None,
        due_from: datetime | None = None,
        due_to: datetime | None = None,
        search: str | None = None,
        skip: int = 0,
        limit: int = 50,
    ) -> task_schema.TaskCollection:
        mapped_statuses = {models.TaskStatus(status.value) for status in statuses} if statuses else None
        mapped_priorities = {models.TaskPriority(priority.value) for priority in priorities} if priorities else None
        tag_names = {tag for tag in tags} if tags else None

        records, total = self._repository.list(
            db,
            user_id=user_id,
            statuses=mapped_statuses,
            priorities=mapped_priorities,
            tag_names=tag_names,
            due_from=due_from,
            due_to=due_to,
            search=search,
            skip=skip,
            limit=limit,
        )

        items = [self._to_task(record) for record in records]
        return task_schema.TaskCollection(total=total, items=items)

    def search_tasks(
        self,
        db: Session,
        *,
        user_id: str,
        query: str,
        due_from: datetime | None = None,
        due_to: datetime | None = None,
        limit: int = 50,
    ) -> list[task_schema.Task]:
        records, _ = self._repository.list(
            db,
            user_id=user_id,
            due_from=due_from,
            due_to=due_to,
            search=query,
            limit=limit,
        )
        return [self._to_task(record) for record in records]

    def create_task(
        self,
        db: Session,
        task_in: task_schema.TaskCreate,
    ) -> task_schema.Task:
        record = self._repository.create(db, task_in)
        return self._to_task(record)

    def update_task(
        self,
        db: Session,
        task_db: models.Task,
        task_in: task_schema.TaskUpdate,
    ) -> task_schema.Task:
        record = self._repository.update(db, task_db=task_db, task_in=task_in)
        return self._to_task(record)

    def delete_task(self, db: Session, task_db: models.Task) -> None:
        self._repository.delete(db, task_db)

    def bulk_complete(
        self,
        db: Session,
        *,
        user_id: str,
        task_ids: list[str],
        completed: bool = True,
    ) -> list[task_schema.Task]:
        status = models.TaskStatus.completed if completed else models.TaskStatus.pending
        records = self._repository.bulk_set_status(
            db,
            user_id=user_id,
            task_ids=task_ids,
            status=status,
        )
        return [self._to_task(record) for record in records]

    def summary(
        self,
        db: Session,
        *,
        user_id: str,
        reference: datetime | None = None,
    ) -> task_schema.TaskStatistics:
        return self._repository.summary(db, user_id=user_id, reference=reference)

    def _to_task(self, model: models.Task) -> task_schema.Task:
        tags = [link.tag.name for link in model.tag_links if link.tag is not None]
        reminders = [
            task_schema.TaskReminder(
                id=reminder.id,
                remind_at=self._coerce_datetime(reminder.remind_at),
                timezone=reminder.timezone,
                channel=(
                    task_schema.NotificationChannel(reminder.channel.value)
                    if reminder.channel is not None
                    else task_schema.NotificationChannel.push
                ),
                repeat_rule=(
                    task_schema.ReminderRepeatRule(reminder.repeat_rule.value)
                    if reminder.repeat_rule is not None
                    else task_schema.ReminderRepeatRule.none
                ),
                repeat_every=reminder.repeat_every or 1,
                active=True if reminder.active is None else bool(reminder.active),
                expires_at=self._coerce_optional_datetime(reminder.expires_at),
                created_at=self._coerce_datetime(reminder.created_at),
                updated_at=self._coerce_optional_datetime(reminder.updated_at),
                last_triggered_at=self._coerce_optional_datetime(reminder.last_triggered_at),
            )
            for reminder in sorted(model.reminders, key=lambda item: item.remind_at)
        ]

        return task_schema.Task(
            id=model.id,
            user_id=model.user_id,
            title=model.title,
            description=model.description,
            due_at=self._coerce_optional_datetime(model.due_at),
            all_day=bool(model.all_day),
            priority=task_schema.TaskPriority(model.priority.value),
            status=task_schema.TaskStatus(model.status.value),
            order_index=model.order_index,
            related_entity_id=model.related_entity_id,
            related_entity_type=
            (
                task_schema.TaskAssociationType(model.related_entity_type.value)
                if model.related_entity_type is not None
                else None
            ),
            created_at=self._coerce_datetime(model.created_at),
            updated_at=self._coerce_optional_datetime(model.updated_at),
            completed_at=self._coerce_optional_datetime(model.completed_at),
            tags=tags,
            reminders=reminders,
        )

    def _coerce_datetime(self, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value

    def _coerce_optional_datetime(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return self._coerce_datetime(value)
