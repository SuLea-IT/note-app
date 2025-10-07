from __future__ import annotations

from datetime import datetime, timezone
from itertools import chain
from typing import Iterable

from sqlalchemy.orm import Session

from ..schemas import search as search_schema
from ..schemas import task as task_schema
from .audio_note_service import AudioNoteService
from .diary_service import DiaryService
from .habit_service import HabitService
from .note_service import NoteService
from .task_service import TaskService


class SearchService:
    _TYPE_LABELS: dict[search_schema.SearchResultType, str] = {
        search_schema.SearchResultType.note: 'Notes',
        search_schema.SearchResultType.diary: 'Diaries',
        search_schema.SearchResultType.task: 'Tasks',
        search_schema.SearchResultType.habit: 'Habits',
        search_schema.SearchResultType.audio_note: 'Audio Notes',
    }

    def __init__(
        self,
        note_service: NoteService | None = None,
        diary_service: DiaryService | None = None,
        habit_service: HabitService | None = None,
        task_service: TaskService | None = None,
        audio_note_service: AudioNoteService | None = None,
    ) -> None:
        self._note_service = note_service or NoteService()
        self._diary_service = diary_service or DiaryService()
        self._habit_service = habit_service or HabitService()
        self._task_service = task_service or TaskService()
        self._audio_note_service = audio_note_service or AudioNoteService()

    def search(
        self,
        db: Session,
        *,
        user_id: str,
        query: str,
        locale: str,
        types: Iterable[search_schema.SearchResultType] | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        limit: int = 50,
    ) -> search_schema.SearchResponse:
        if not query.strip():
            return search_schema.SearchResponse(
                query=query,
                total=0,
                results=[],
                sections=[],
            )

        type_set = set(types) if types else set(search_schema.SearchResultType)
        active_types = [item for item in search_schema.SearchResultType if item in type_set]
        if not active_types:
            return search_schema.SearchResponse(query=query, total=0, results=[], sections=[])

        per_type_limit = max(1, limit // len(active_types)) if limit > 0 else 50

        results_by_type: dict[search_schema.SearchResultType, list[search_schema.SearchResult]] = {}

        if search_schema.SearchResultType.note in active_types:
            notes = self._note_service.search_notes(
                db=db,
                user_id=user_id,
                locale=locale,
                query=query,
                limit=per_type_limit,
            )
            results_by_type[search_schema.SearchResultType.note] = [
                self._from_note(summary) for summary in notes
            ]

        if search_schema.SearchResultType.diary in active_types:
            diaries = self._diary_service.search_diaries(
                db=db,
                user_id=user_id,
                locale=locale,
                query=query,
                start_date=start_date,
                end_date=end_date,
                limit=per_type_limit,
            )
            results_by_type[search_schema.SearchResultType.diary] = [
                self._from_diary(summary) for summary in diaries
            ]

        if search_schema.SearchResultType.task in active_types:
            tasks = self._task_service.search_tasks(
                db=db,
                user_id=user_id,
                query=query,
                due_from=start_date,
                due_to=end_date,
                limit=per_type_limit,
            )
            results_by_type[search_schema.SearchResultType.task] = [
                self._from_task(task) for task in tasks
            ]

        if search_schema.SearchResultType.habit in active_types:
            habits = self._habit_service.search_habits(
                db=db,
                user_id=user_id,
                locale=locale,
                query=query,
                limit=per_type_limit,
            )
            results_by_type[search_schema.SearchResultType.habit] = [
                self._from_habit(summary) for summary in habits
            ]

        if search_schema.SearchResultType.audio_note in active_types:
            collection = self._audio_note_service.list_audio_notes(
                db=db,
                user_id=user_id,
                search=query,
                limit=per_type_limit,
            )
            results_by_type[search_schema.SearchResultType.audio_note] = [
                self._from_audio_note(item) for item in collection.items
            ]

        all_results = list(chain.from_iterable(results_by_type.values()))
        all_results.sort(key=self._sort_key, reverse=True)

        if limit > 0:
            all_results = all_results[:limit]

        sections = []
        for result_type in active_types:
            filtered = [item for item in all_results if item.type == result_type]
            if not filtered:
                continue
            label = self._TYPE_LABELS.get(result_type, result_type.value.title())
            sections.append(
                search_schema.SearchSection(
                    type=result_type,
                    label=label,
                    results=filtered,
                )
            )

        return search_schema.SearchResponse(
            query=query,
            total=len(all_results),
            results=all_results,
            sections=sections,
        )

    def _sort_key(self, result: search_schema.SearchResult) -> tuple[bool, datetime]:
        if result.date is None:
            return (False, datetime(1970, 1, 1, tzinfo=timezone.utc))
        date_value = result.date
        if date_value.tzinfo is None:
            date_value = date_value.replace(tzinfo=timezone.utc)
        return (True, date_value)

    def _from_note(self, summary) -> search_schema.SearchResult:
        metadata = {
            'category': summary.category.value,
            'has_attachment': summary.has_attachment,
            'progress_percent': summary.progress_percent,
        }
        return search_schema.SearchResult(
            id=summary.id,
            type=search_schema.SearchResultType.note,
            title=summary.title,
            excerpt=self._clip(summary.preview or summary.content),
            date=summary.date,
            tags=summary.tags,
            metadata=metadata,
        )

    def _from_diary(self, summary) -> search_schema.SearchResult:
        metadata = {
            'category': summary.category.value,
            'mood': summary.mood,
            'weather': summary.weather,
            'can_share': summary.can_share,
        }
        return search_schema.SearchResult(
            id=summary.id,
            type=search_schema.SearchResultType.diary,
            title=summary.title,
            excerpt=self._clip(summary.preview or summary.content),
            date=summary.date,
            tags=summary.tags,
            metadata=metadata,
        )

    def _from_task(self, task: task_schema.Task) -> search_schema.SearchResult:
        metadata = {
            'status': task.status.value,
            'priority': task.priority.value,
            'has_attachment': bool(task.tags),
        }
        return search_schema.SearchResult(
            id=task.id,
            type=search_schema.SearchResultType.task,
            title=task.title,
            excerpt=self._clip(task.description),
            date=task.due_at or task.created_at,
            tags=task.tags,
            metadata=metadata,
        )

    def _from_habit(self, summary) -> search_schema.SearchResult:
        metadata = {
            'status': summary.status.value,
            'time_label': summary.time_label,
            'completed_today': summary.completed_today,
            'streak_days': summary.streak_days,
        }
        return search_schema.SearchResult(
            id=summary.id,
            type=search_schema.SearchResultType.habit,
            title=summary.title,
            excerpt=self._clip(summary.description or summary.time_label),
            date=None,
            tags=[],
            metadata=metadata,
        )

    def _from_audio_note(self, audio_note) -> search_schema.SearchResult:
        metadata = {
            'status': audio_note.transcription_status.value,
            'duration_seconds': audio_note.duration_seconds,
            'mime_type': audio_note.mime_type,
        }
        reference_date = audio_note.recorded_at or audio_note.updated_at or audio_note.created_at
        return search_schema.SearchResult(
            id=audio_note.id,
            type=search_schema.SearchResultType.audio_note,
            title=audio_note.title,
            excerpt=self._clip(audio_note.description or audio_note.transcription_text),
            date=reference_date,
            tags=[],
            metadata=metadata,
        )

    def _clip(self, value: str | None, length: int = 160) -> str | None:
        if not value:
            return None
        text = value.strip()
        if len(text) <= length:
            return text
        return f"{text[:length].rstrip()}…"

