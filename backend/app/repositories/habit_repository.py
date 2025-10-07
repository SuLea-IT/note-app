from __future__ import annotations

import uuid

from datetime import date, datetime

from sqlalchemy import func, or_
from sqlalchemy.orm import Session, selectinload

from .. import models
from ..schemas import habit


class HabitRepository:
    def get(self, db: Session, habit_id: str) -> models.Habit | None:
        return (
            db.query(models.Habit)
            .options(
                selectinload(models.Habit.translations),
                selectinload(models.Habit.entries),
            )
            .filter(models.Habit.id == habit_id)
            .first()
        )

    def get_all(
        self, db: Session, user_id: str | None = None, skip: int = 0, limit: int = 100
    ) -> list[models.Habit]:
        query = db.query(models.Habit).options(
            selectinload(models.Habit.translations),
            selectinload(models.Habit.entries),
        )
        if user_id is not None:
            query = query.filter(models.Habit.user_id == user_id)
        return query.order_by(models.Habit.created_at.desc()).offset(skip).limit(limit).all()

    def search(
        self,
        db: Session,
        *,
        user_id: str,
        query: str,
        limit: int = 50,
    ) -> list[models.Habit]:
        term = f"%{query.lower()}%"
        stmt = (
            db.query(models.Habit)
            .outerjoin(models.HabitTranslation)
            .options(
                selectinload(models.Habit.translations),
                selectinload(models.Habit.entries),
            )
            .filter(models.Habit.user_id == user_id)
            .filter(
                or_(
                    func.lower(models.Habit.title).like(term),
                    func.lower(models.Habit.description).like(term),
                    func.lower(models.Habit.time_label).like(term),
                    func.lower(models.HabitTranslation.title).like(term),
                    func.lower(models.HabitTranslation.description).like(term),
                )
            )
            .order_by(models.Habit.created_at.desc())
            .limit(limit)
        )
        return stmt.distinct().all()

    def create(self, db: Session, habit_in: habit.HabitCreate) -> models.Habit:
        habit_id = str(uuid.uuid4())
        db_habit = models.Habit(
            id=habit_id,
            user_id=habit_in.user_id,
            title=habit_in.title,
            description=habit_in.description,
            time_label=habit_in.time_label,
            status=models.HabitStatus(habit_in.status.value),
            reminder_time=habit_in.reminder_time,
            repeat_rule=habit_in.repeat_rule,
            accent_color=habit_in.accent_color or 0xFF7C4DFF,
            default_locale=habit_in.default_locale,
        )

        translations = list(habit_in.translations or [])
        locales = {item.locale for item in translations}
        if habit_in.default_locale not in locales:
            translations.append(
                habit.HabitTranslationPayload(
                    locale=habit_in.default_locale,
                    title=habit_in.title,
                    description=habit_in.description,
                    time_label=habit_in.time_label,
                )
            )

        for payload in translations:
            db_habit.translations.append(
                models.HabitTranslation(
                    locale=payload.locale,
                    title=payload.title,
                    description=payload.description,
                    time_label=payload.time_label,
                )
            )

        db.add(db_habit)
        db.commit()
        db.refresh(db_habit)
        return db_habit

    def update(
        self, db: Session, habit_db: models.Habit, habit_in: habit.HabitUpdate
    ) -> models.Habit:
        update_fields = habit_in.model_dump(exclude={'translations'}, exclude_none=True)

        if 'status' in update_fields:
            update_fields['status'] = models.HabitStatus(update_fields['status'].value)
        if 'accent_color' in update_fields and not update_fields['accent_color']:
            update_fields['accent_color'] = 0xFF7C4DFF

        for key, value in update_fields.items():
            setattr(habit_db, key, value)

        if habit_in.translations is not None:
            existing = {item.locale: item for item in habit_db.translations}
            for payload in habit_in.translations:
                translation = existing.get(payload.locale)
                if translation is None:
                    translation = models.HabitTranslation(
                        locale=payload.locale,
                        title=payload.title,
                        description=payload.description,
                        time_label=payload.time_label,
                    )
                    habit_db.translations.append(translation)
                else:
                    translation.title = payload.title
                    translation.description = payload.description
                    translation.time_label = payload.time_label

        db.add(habit_db)
        db.commit()
        db.refresh(habit_db)
        return habit_db

    def delete(self, db: Session, habit_db: models.Habit) -> models.Habit:
        db.delete(habit_db)
        db.commit()
        return habit_db

    def upsert_entry(
        self,
        db: Session,
        *,
        habit_id: str,
        entry_date: date,
        status: models.HabitStatus,
        completed_at: datetime | None = None,
        duration_minutes: int | None = None,
    ) -> models.HabitEntry:
        record = (
            db.query(models.HabitEntry)
            .filter(
                models.HabitEntry.habit_id == habit_id,
                models.HabitEntry.entry_date == entry_date,
            )
            .first()
        )
        if record is None:
            record = models.HabitEntry(
                habit_id=habit_id,
                entry_date=entry_date,
            )
            db.add(record)

        record.status = status
        record.completed_at = completed_at
        record.duration_minutes = duration_minutes

        db.flush()
        return record

    def remove_entry(self, db: Session, *, habit_id: str, entry_date: date) -> None:
        db.query(models.HabitEntry).filter(
            models.HabitEntry.habit_id == habit_id,
            models.HabitEntry.entry_date == entry_date,
        ).delete(synchronize_session=False)
