from __future__ import annotations

from datetime import datetime, timezone
from typing import Iterable

from sqlalchemy.orm import Session

from ..repositories.quick_action_repository import QuickActionRepository
from ..schemas.habit import HabitStatus
from ..schemas.home import HomeFeed, HomeHabit, QuickAction
from ..services.habit_service import HabitService
from ..services.note_service import NoteService
from ..services.task_service import TaskService


class HomeService:
    """Compose the home feed based on note and habit data."""

    def __init__(
        self,
        note_service: NoteService | None = None,
        habit_service: HabitService | None = None,
        task_service: TaskService | None = None,
        quick_action_repository: QuickActionRepository | None = None,
    ) -> None:
        self._note_service = note_service or NoteService()
        self._habit_service = habit_service or HabitService()
        self._task_service = task_service or TaskService()
        self._quick_action_repository = quick_action_repository or QuickActionRepository()

    def get_feed(
        self,
        db: Session,
        user_id: str,
        locale: str,
    ) -> HomeFeed:
        note_feed = self._note_service.get_feed(db=db, user_id=user_id, locale=locale)
        habit_feed = self._habit_service.get_feed(db=db, user_id=user_id, locale=locale)
        tasks_summary = self._task_service.summary(
            db=db,
            user_id=user_id,
            reference=datetime.now(timezone.utc),
        )

        quick_actions = self._quick_actions(db, locale)
        habits = [
            HomeHabit(
                id=entry.id,
                label=entry.title,
                time_range=entry.time_label or '',
                notes=entry.description or '',
                is_completed=entry.status == HabitStatus.completed,
            )
            for entry in habit_feed.entries
        ]

        return HomeFeed(
            sections=note_feed.sections,
            quick_actions=quick_actions,
            habits=habits,
            tasks=tasks_summary,
        )

    def _quick_actions(self, db: Session, locale: str) -> list[QuickAction]:
        records = self._quick_action_repository.list(db)
        if not records:
            return []

        preferences = self._locale_preferences(locale)
        result: list[QuickAction] = []
        for record in records:
            translation = self._select_translation(record.translations, preferences, record.default_locale)
            title = (translation.title if translation else record.default_title) or record.id
            subtitle = (translation.subtitle if translation else record.default_subtitle) or ''
            result.append(
                QuickAction(
                    id=record.id,
                    title=title,
                    subtitle=subtitle,
                    background_color=record.background_color,
                    foreground_color=record.foreground_color,
                    icon=record.icon,
                )
            )
        return result

    def _select_translation(
        self,
        translations: Iterable,
        preferences: list[str],
        default_locale: str,
    ):
        items = list(translations)
        if not items:
            return None

        normalized = [value.lower() for value in preferences]
        # ensure default locale is considered toward the end
        default_norm = (default_locale or '').lower()
        if default_norm:
            normalized.append(default_norm)

        for target in normalized:
            for item in items:
                locale = (getattr(item, 'locale', '') or '').lower()
                title = getattr(item, 'title', '')
                if locale == target and title:
                    return item
        return None

    def _locale_preferences(self, requested: str) -> list[str]:
        values: list[str] = []
        if requested:
            norm = requested.lower()
            values.append(norm)
            primary = norm.split('-')[0]
            if primary and primary != norm:
                values.append(primary)
        values.extend(['zh-cn', 'zh', 'en'])
        return values
