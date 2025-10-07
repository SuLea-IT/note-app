from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import case, or_
from sqlalchemy.orm import Session, selectinload

from .. import models
from ..schemas import task as task_schema


class TaskRepository:
    def get(self, db: Session, task_id: str) -> models.Task | None:
        return (
            db.query(models.Task)
            .options(
                selectinload(models.Task.reminders),
                selectinload(models.Task.tag_links).selectinload(models.TaskTagLink.tag),
            )
            .filter(models.Task.id == task_id)
            .first()
        )

    def list(
        self,
        db: Session,
        *,
        user_id: str,
        statuses: set[models.TaskStatus] | None = None,
        priorities: set[models.TaskPriority] | None = None,
        tag_names: set[str] | None = None,
        due_from: datetime | None = None,
        due_to: datetime | None = None,
        search: str | None = None,
        skip: int = 0,
        limit: int = 50,
    ) -> tuple[list[models.Task], int]:
        query = (
            db.query(models.Task)
            .options(
                selectinload(models.Task.reminders),
                selectinload(models.Task.tag_links).selectinload(models.TaskTagLink.tag),
            )
            .filter(models.Task.user_id == user_id)
        )

        if statuses:
            query = query.filter(models.Task.status.in_(tuple(statuses)))

        if priorities:
            query = query.filter(models.Task.priority.in_(tuple(priorities)))

        if due_from is not None:
            query = query.filter(models.Task.due_at >= due_from)

        if due_to is not None:
            query = query.filter(models.Task.due_at <= due_to)

        if search:
            pattern = f'%{search.strip()}%'
            query = query.filter(
                or_(
                    models.Task.title.ilike(pattern),
                    models.Task.description.ilike(pattern),
                )
            )

        if tag_names:
            normalized = {name.strip() for name in tag_names if name and name.strip()}
            if normalized:
                query = (
                    query.join(models.Task.tag_links)
                    .join(models.TaskTagLink.tag)
                    .filter(models.TaskTag.name.in_(tuple(normalized)))
                    .distinct()
                )

        total = query.count()

        orderings = (
            case((models.Task.due_at.is_(None), 1), else_=0),
            models.Task.due_at.asc(),
            models.Task.order_index.asc(),
            models.Task.created_at.desc(),
        )

        items = (
            query.order_by(*orderings)
            .offset(max(skip, 0))
            .limit(max(limit, 1))
            .all()
        )
        return items, int(total)

    def create(self, db: Session, task_in: task_schema.TaskCreate) -> models.Task:
        task_id = str(uuid.uuid4())
        priority = models.TaskPriority(task_in.priority.value)
        status = models.TaskStatus(task_in.status.value)
        related_type = (
            models.TaskAssociationType(task_in.related_entity_type.value)
            if task_in.related_entity_type is not None
            else None
        )

        db_task = models.Task(
            id=task_id,
            user_id=task_in.user_id,
            title=task_in.title,
            description=task_in.description,
            due_at=task_in.due_at,
            all_day=task_in.all_day,
            priority=priority,
            status=status,
            order_index=task_in.order_index if task_in.order_index is not None else 0,
            related_entity_id=task_in.related_entity_id,
            related_entity_type=related_type,
        )

        self._apply_completion_timestamp(db_task, status)

        self._sync_tags(
            db,
            task_db=db_task,
            user_id=task_in.user_id,
            tags=list(task_in.tags or []),
        )
        self._sync_reminders(
            db,
            task_db=db_task,
            reminders=list(task_in.reminders or []),
        )

        db.add(db_task)
        db.commit()
        db.refresh(db_task)
        return db_task

    def update(
        self,
        db: Session,
        *,
        task_db: models.Task,
        task_in: task_schema.TaskUpdate,
    ) -> models.Task:
        task_db.title = task_in.title
        task_db.description = task_in.description
        task_db.due_at = task_in.due_at
        task_db.all_day = task_in.all_day
        task_db.priority = models.TaskPriority(task_in.priority.value)
        task_db.status = models.TaskStatus(task_in.status.value)
        task_db.order_index = task_in.order_index if task_in.order_index is not None else task_db.order_index
        task_db.related_entity_id = task_in.related_entity_id
        task_db.related_entity_type = (
            models.TaskAssociationType(task_in.related_entity_type.value)
            if task_in.related_entity_type is not None
            else None
        )

        self._apply_completion_timestamp(task_db, task_db.status)

        if task_in.tags is not None:
            self._sync_tags(
                db,
                task_db=task_db,
                user_id=task_db.user_id,
                tags=list(task_in.tags),
            )

        if task_in.reminders is not None:
            self._sync_reminders(
                db,
                task_db=task_db,
                reminders=list(task_in.reminders),
            )

        db.add(task_db)
        db.commit()
        db.refresh(task_db)
        return task_db

    def delete(self, db: Session, task_db: models.Task) -> None:
        db.delete(task_db)
        db.commit()

    def bulk_set_status(
        self,
        db: Session,
        *,
        user_id: str | None,
        task_ids: list[str],
        status: models.TaskStatus,
    ) -> list[models.Task]:
        if not task_ids:
            return []

        tasks = (
            db.query(models.Task)
            .options(
                selectinload(models.Task.reminders),
                selectinload(models.Task.tag_links).selectinload(models.TaskTagLink.tag),
            )
            .filter(models.Task.id.in_(task_ids))
            .filter(models.Task.user_id == user_id)
            .all()
        )

        now = datetime.now(timezone.utc)
        for item in tasks:
            item.status = status
            if status == models.TaskStatus.completed:
                item.completed_at = item.completed_at or now
            else:
                item.completed_at = None

        db.commit()
        for item in tasks:
            db.refresh(item)
        return tasks

    def summary(
        self,
        db: Session,
        *,
        user_id: str,
        reference: datetime | None = None,
    ) -> task_schema.TaskStatistics:
        now = reference.astimezone(timezone.utc) if reference else datetime.now(timezone.utc)
        start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = start_of_day + timedelta(days=1)
        end_of_week = start_of_day + timedelta(days=7)

        pending_states = (models.TaskStatus.pending, models.TaskStatus.in_progress)

        base = db.query(models.Task).filter(models.Task.user_id == user_id)

        pending_today = (
            base.filter(models.Task.status.in_(pending_states))
            .filter(models.Task.due_at >= start_of_day)
            .filter(models.Task.due_at < end_of_day)
            .count()
        )

        overdue = (
            base.filter(models.Task.status.in_(pending_states))
            .filter(models.Task.due_at.isnot(None))
            .filter(models.Task.due_at < now)
            .count()
        )

        upcoming_week = (
            base.filter(models.Task.status.in_(pending_states))
            .filter(models.Task.due_at >= end_of_day)
            .filter(models.Task.due_at < end_of_week)
            .count()
        )

        completed_today = (
            base.filter(models.Task.status == models.TaskStatus.completed)
            .filter(models.Task.completed_at.isnot(None))
            .filter(models.Task.completed_at >= start_of_day)
            .filter(models.Task.completed_at < end_of_day)
            .count()
        )

        return task_schema.TaskStatistics(
            pending_today=pending_today,
            overdue=overdue,
            upcoming_week=upcoming_week,
            completed_today=completed_today,
        )

    def _apply_completion_timestamp(self, task: models.Task, status: models.TaskStatus) -> None:
        if status == models.TaskStatus.completed:
            task.completed_at = task.completed_at or datetime.now(timezone.utc)
        elif status in {models.TaskStatus.pending, models.TaskStatus.in_progress}:
            task.completed_at = None

    def _sync_tags(
        self,
        db: Session,
        *,
        task_db: models.Task,
        user_id: str,
        tags: list[str],
    ) -> None:
        normalized = {tag.strip() for tag in tags if tag and tag.strip()}
        existing_links = list(task_db.tag_links)

        for link in existing_links:
            if link.tag.name not in normalized:
                task_db.tag_links.remove(link)
                db.delete(link)

        if not normalized:
            return

        remaining = {link.tag.name for link in task_db.tag_links}
        pending = normalized - remaining
        if not pending:
            return

        existing_tags = (
            db.query(models.TaskTag)
            .filter(models.TaskTag.user_id == user_id)
            .filter(models.TaskTag.name.in_(tuple(pending)))
            .all()
        )
        cache = {tag.name: tag for tag in existing_tags}

        for name in pending:
            tag = cache.get(name)
            if tag is None:
                tag = models.TaskTag(user_id=user_id, name=name)
                db.add(tag)
                db.flush()
            task_db.tag_links.append(models.TaskTagLink(tag=tag))

    def _sync_reminders(
        self,
        db: Session,
        *,
        task_db: models.Task,
        reminders: list[task_schema.TaskReminderUpsert],
    ) -> None:
        if not reminders:
            for reminder in list(task_db.reminders):
                task_db.reminders.remove(reminder)
                db.delete(reminder)
            return

        existing_by_id: dict[int, models.TaskReminder] = {
            reminder.id: reminder
            for reminder in task_db.reminders
            if reminder.id is not None
        }
        anonymous = [reminder for reminder in task_db.reminders if reminder.id is None]
        retained: set[models.TaskReminder] = set()

        for payload in reminders:
            tz_name = (payload.timezone or 'UTC').strip() or 'UTC'
            try:
                tzinfo = ZoneInfo(tz_name)
            except Exception:
                tz_name = 'UTC'
                tzinfo = ZoneInfo('UTC')

            remind_at = payload.remind_at
            if remind_at.tzinfo is None:
                localized = remind_at.replace(tzinfo=tzinfo)
            else:
                localized = remind_at.astimezone(tzinfo)
            remind_at_utc = localized.astimezone(timezone.utc)

            expires_at_utc = None
            if payload.expires_at is not None:
                expires_at = payload.expires_at
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=tzinfo)
                else:
                    expires_at = expires_at.astimezone(tzinfo)
                expires_at_utc = expires_at.astimezone(timezone.utc)

            channel = models.NotificationChannel(payload.channel.value)
            repeat_rule = models.TaskReminderRepeat(payload.repeat_rule.value)
            repeat_every = max(payload.repeat_every, 1)
            active = bool(payload.active)

            reminder_db = None
            if payload.id is not None:
                reminder_db = existing_by_id.pop(payload.id, None)

            if reminder_db is None:
                for candidate in list(anonymous):
                    if (
                        candidate.remind_at == remind_at_utc
                        and candidate.timezone == tz_name
                        and candidate.channel == channel
                        and candidate.repeat_rule == repeat_rule
                        and candidate.repeat_every == repeat_every
                    ):
                        reminder_db = candidate
                        anonymous.remove(candidate)
                        break

            if reminder_db is None:
                reminder_db = models.TaskReminder()
                task_db.reminders.append(reminder_db)

            reminder_db.remind_at = remind_at_utc
            reminder_db.timezone = tz_name
            reminder_db.channel = channel
            reminder_db.repeat_rule = repeat_rule
            reminder_db.repeat_every = repeat_every
            reminder_db.active = active
            reminder_db.expires_at = expires_at_utc
            retained.add(reminder_db)

        for reminder in list(task_db.reminders):
            if reminder not in retained:
                task_db.reminders.remove(reminder)
                db.delete(reminder)
