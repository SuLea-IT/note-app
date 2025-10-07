from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from typing import Iterable, Mapping

from sqlalchemy.orm import Session

from .. import models
from ..repositories.habit_repository import HabitRepository
from ..schemas import habit


class HabitService:
    def __init__(self, repository: HabitRepository | None = None) -> None:
        self._repository = repository or HabitRepository()

    def get_habit_model(self, db: Session, habit_id: str) -> models.Habit | None:
        return self._repository.get(db, habit_id)

    def get_habit(
        self, db: Session, habit_id: str, locale: str | None = None
    ) -> habit.Habit | None:
        record = self._repository.get(db, habit_id)
        if record is None:
            return None
        return self._to_habit(record, locale or record.default_locale)

    def get_all_habits(
        self,
        db: Session,
        user_id: str,
        locale: str,
        skip: int = 0,
        limit: int = 100,
    ) -> list[habit.Habit]:
        records = self._repository.get_all(
            db, user_id=user_id, skip=skip, limit=limit
        )
        return [self._to_habit(item, locale) for item in records]

    def create_habit(
        self, db: Session, habit_in: habit.HabitCreate, locale: str | None = None
    ) -> habit.Habit:
        record = self._repository.create(db, habit_in)
        refreshed = self._repository.get(db, record.id)
        return self._to_habit(refreshed or record, locale or habit_in.default_locale)

    def update_habit(
        self,
        db: Session,
        habit_db: models.Habit,
        habit_in: habit.HabitUpdate,
        locale: str | None = None,
    ) -> habit.Habit:
        previous_status = habit_db.status
        record = self._repository.update(db, habit_db, habit_in)

        status_payload = habit_in.status.value if habit_in.status is not None else None
        status_changed = (
            status_payload is not None
            and models.HabitStatus(status_payload) != previous_status
        )

        if status_changed:
            self._sync_today_entry(
                db,
                habit_id=record.id,
                status=models.HabitStatus(status_payload),
            )

        db.commit()
        refreshed = self._repository.get(db, record.id)
        target = refreshed or record
        return self._to_habit(target, locale or target.default_locale)

    def delete_habit(self, db: Session, habit_db: models.Habit) -> None:
        self._repository.delete(db, habit_db)

    def get_feed(
        self, db: Session, user_id: str, locale: str, limit: int = 100
    ) -> habit.HabitFeed:
        records = self._repository.get_all(db, user_id=user_id, limit=limit)
        total_habits = len(records)
        entries_by_date = self._group_entries_by_date(records)
        days = self._build_days(total_habits, entries_by_date)
        overview = self._build_overview(records, entries_by_date)
        summaries = [self._to_summary(item, locale) for item in records]
        history = self._build_history(records, locale)
        return habit.HabitFeed(
            days=days,
            entries=summaries,
            overview=overview,
            history=history,
        )

    def search_habits(
        self,
        db: Session,
        *,
        user_id: str,
        locale: str,
        query: str,
        limit: int = 50,
    ) -> list[habit.HabitSummary]:
        records = self._repository.search(
            db,
            user_id=user_id,
            query=query,
            limit=limit,
        )
        return [self._to_summary(item, locale) for item in records]

    def _to_habit(self, model: models.Habit, locale: str) -> habit.Habit:
        translation = self._select_translation(model.translations, locale, model.default_locale)
        title = (translation.title if translation else model.title) or 'Untitled habit'
        description = translation.description if translation else model.description
        time_label = translation.time_label if translation else model.time_label
        status = self._to_schema_status(model.status)

        streak_days = self._streak_for_habit(model.entries)
        today = self._today()
        today_entry = self._entry_for_date(model.entries, today)
        latest_entry = model.entries[0] if model.entries else None

        return habit.Habit(
            id=model.id,
            user_id=model.user_id,
            title=title,
            description=description,
            time_label=time_label,
            status=status,
            reminder_time=model.reminder_time,
            repeat_rule=model.repeat_rule,
            accent_color=model.accent_color or 0xFF7C4DFF,
            default_locale=model.default_locale,
            created_at=model.created_at.replace(tzinfo=None) if model.created_at else datetime.utcnow(),
            updated_at=model.updated_at.replace(tzinfo=None) if model.updated_at else None,
            translations=[
                habit.HabitTranslation(
                    locale=item.locale,
                    title=item.title,
                    description=item.description,
                    time_label=item.time_label,
                    created_at=item.created_at.replace(tzinfo=None)
                    if item.created_at
                    else None,
                    updated_at=item.updated_at.replace(tzinfo=None)
                    if item.updated_at
                    else None,
                )
                for item in model.translations
            ],
            streak_days=streak_days,
            completed_today=today_entry.status == models.HabitStatus.completed if today_entry else False,
        latest_entry=self._to_history_entry(latest_entry, title=title) if latest_entry else None,
        )

    def _to_summary(self, model: models.Habit, locale: str) -> habit.HabitSummary:
        translation = self._select_translation(model.translations, locale, model.default_locale)
        title = (translation.title if translation else model.title) or 'Untitled habit'
        description = translation.description if translation else model.description
        time_label = translation.time_label if translation else model.time_label
        status = self._to_schema_status(model.status)
        streak_days = self._streak_for_habit(model.entries)
        today_entry = self._entry_for_date(model.entries, self._today())

        return habit.HabitSummary(
            id=model.id,
            user_id=model.user_id,
            title=title,
            description=description,
            time_label=time_label,
            status=status,
            reminder_time=model.reminder_time,
            repeat_rule=model.repeat_rule,
            accent_color=model.accent_color or 0xFF7C4DFF,
            streak_days=streak_days,
            completed_today=today_entry.status == models.HabitStatus.completed if today_entry else False,
        )

    def _build_days(
        self,
        total_habits: int,
        entries_by_date: Mapping[date, list[models.HabitEntry]],
        window: int = 14,
    ) -> list[habit.HabitDay]:
        total = max(1, total_habits)
        today = self._today()
        days: list[habit.HabitDay] = []

        for offset in range(window - 1, -1, -1):
            target = today - timedelta(days=offset)
            entries = entries_by_date.get(target, [])
            completed_count = sum(
                1 for entry in entries if entry.status == models.HabitStatus.completed
            )
            completion_rate = (
                completed_count / total if total > 0 else None
            )
            days.append(
                habit.HabitDay(
                    date=target,
                    is_today=offset == 0,
                    completed_count=completed_count,
                    total_count=total,
                    completion_rate=completion_rate,
                )
            )
        return days

    def _build_overview(
        self,
        records: list[models.Habit],
        entries_by_date: Mapping[date, list[models.HabitEntry]],
    ) -> habit.HabitOverview:
        total_habits = len(records)
        if total_habits == 0:
            return habit.HabitOverview(
                focus_minutes=0,
                completed_streak=0,
                total_habits=0,
                completion_rate=0.0,
                active_days=0,
            )

        today = self._today()
        focus_minutes = 0
        total_completed = 0
        active_days = 0

        for target_date, entries in entries_by_date.items():
            if entries:
                active_days += 1
            for entry in entries:
                if entry.duration_minutes:
                    focus_minutes += entry.duration_minutes
                elif entry.status == models.HabitStatus.completed:
                    focus_minutes += 30
                if entry.status == models.HabitStatus.completed:
                    total_completed += 1

        completed_streak = self._overall_streak(entries_by_date, today)

        window_days = min(7, len(entries_by_date) or 7)
        total_possible = total_habits * window_days
        recent_window_dates = {today - timedelta(days=offset) for offset in range(window_days)}
        recent_completed = sum(
            1
            for target_date in recent_window_dates
            for entry in entries_by_date.get(target_date, [])
            if entry.status == models.HabitStatus.completed
        )
        completion_rate = (
            (recent_completed / total_possible) if total_possible else 0.0
        )

        return habit.HabitOverview(
            focus_minutes=focus_minutes,
            completed_streak=completed_streak,
            total_habits=total_habits,
            completion_rate=round(completion_rate, 2),
            active_days=active_days,
        )

    def _build_history(
        self,
        records: list[models.Habit],
        locale: str,
        limit: int = 50,
    ) -> list[habit.HabitHistoryEntry]:
        history: list[tuple[models.HabitEntry, str]] = []
        for record in records:
            title = self._resolve_title(record, locale)
            for entry in record.entries:
                history.append((entry, title))
        history.sort(
            key=lambda item: (
                item[0].entry_date,
                item[0].completed_at or datetime.min,
            ),
            reverse=True,
        )
        sliced = history[:limit]
        return [self._to_history_entry(entry, title=title) for entry, title in sliced]

    def _group_entries_by_date(
        self,
        records: list[models.Habit],
    ) -> dict[date, list[models.HabitEntry]]:
        mapping: dict[date, list[models.HabitEntry]] = defaultdict(list)
        for record in records:
            for entry in record.entries:
                mapping[entry.entry_date].append(entry)
        return mapping

    def _sync_today_entry(
        self,
        db: Session,
        *,
        habit_id: str,
        status: models.HabitStatus,
    ) -> None:
        today = self._today()
        if status == models.HabitStatus.completed:
            self._repository.upsert_entry(
                db,
                habit_id=habit_id,
                entry_date=today,
                status=status,
                completed_at=datetime.utcnow(),
                duration_minutes=30,
            )
        elif status == models.HabitStatus.in_progress:
            self._repository.upsert_entry(
                db,
                habit_id=habit_id,
                entry_date=today,
                status=status,
                completed_at=None,
                duration_minutes=None,
            )
        else:
            self._repository.remove_entry(db, habit_id=habit_id, entry_date=today)

    def _select_translation(
        self,
        translations: Iterable[models.HabitTranslation],
        locale: str,
        default_locale: str,
    ) -> models.HabitTranslation | None:
        items = list(translations)
        if not items:
            return None

        targets = self._locale_preferences(locale, default_locale)
        lowered = [(item, item.locale.lower()) for item in items]

        for target in targets:
            for item, candidate in lowered:
                if candidate == target:
                    return item
        return items[0]

    def _locale_preferences(self, requested: str, default: str) -> list[str]:
        preferences: list[str] = []
        for value in (requested, default):
            if not value:
                continue
            norm = value.lower()
            if norm not in preferences:
                preferences.append(norm)
            primary = norm.split('-')[0]
            if primary and primary not in preferences:
                preferences.append(primary)
        return preferences

    def _to_schema_status(self, value: models.HabitStatus | None) -> habit.HabitStatus:
        if isinstance(value, models.HabitStatus):
            raw = value.value
        else:
            raw = str(value or '').lower()
        try:
            return habit.HabitStatus(raw)
        except ValueError:
            return habit.HabitStatus.upcoming

    def _streak_for_habit(self, entries: Iterable[models.HabitEntry]) -> int:
        if not entries:
            return 0
        today = self._today()
        by_date = {entry.entry_date: entry for entry in entries}
        streak = 0
        cursor = today
        while True:
            record = by_date.get(cursor)
            if record and record.status == models.HabitStatus.completed:
                streak += 1
                cursor = cursor - timedelta(days=1)
            else:
                break
        return streak

    def _overall_streak(
        self,
        entries_by_date: Mapping[date, list[models.HabitEntry]],
        today: date,
    ) -> int:
        streak = 0
        cursor = today
        while True:
            records = entries_by_date.get(cursor, [])
            if any(record.status == models.HabitStatus.completed for record in records):
                streak += 1
                cursor = cursor - timedelta(days=1)
            else:
                break
        return streak

    def _entry_for_date(
        self,
        entries: Iterable[models.HabitEntry],
        target: date,
    ) -> models.HabitEntry | None:
        for entry in entries:
            if entry.entry_date == target:
                return entry
        return None

    def _to_history_entry(
        self,
        entry: models.HabitEntry | None,
        *,
        title: str | None = None,
    ) -> habit.HabitHistoryEntry | None:
        if entry is None:
            return None
        return habit.HabitHistoryEntry(
            habit_id=entry.habit_id,
            title=title or entry.habit.title if entry.habit else entry.habit_id,
            date=entry.entry_date,
            status=self._to_schema_status(entry.status),
            completed_at=self._coerce_optional_datetime(entry.completed_at),
            duration_minutes=entry.duration_minutes,
        )

    def _resolve_title(self, model: models.Habit, locale: str) -> str:
        translation = self._select_translation(model.translations, locale, model.default_locale)
        return (translation.title if translation else model.title) or model.id

    def _today(self) -> date:
        return datetime.utcnow().date()

    def _coerce_optional_datetime(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return value.replace(tzinfo=None)


