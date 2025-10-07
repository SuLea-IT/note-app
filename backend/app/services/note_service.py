from __future__ import annotations

from collections import defaultdict
from datetime import datetime
from typing import Iterable

from sqlalchemy.orm import Session

from .. import models
from ..repositories.note_repository import NoteRepository
from ..schemas import note


class NoteService:
    def __init__(self, repository: NoteRepository | None = None) -> None:
        self._repository = repository or NoteRepository()

    def get_note_model(self, db: Session, note_id: str) -> models.Note | None:
        return self._repository.get(db, note_id)

    def get_note(
        self, db: Session, note_id: str, locale: str | None = None
    ) -> note.Note | None:
        record = self._repository.get(db, note_id)
        if record is None:
            return None
        return self._to_note(record, locale or record.default_locale)

    def get_all_notes(
        self,
        db: Session,
        user_id: str,
        locale: str,
        skip: int = 0,
        limit: int = 100,
    ) -> list[note.Note]:
        records = self._repository.get_all(
            db, user_id=user_id, skip=skip, limit=limit
        )
        return [self._to_note(item, locale) for item in records]

    def create_note(
        self, db: Session, note_in: note.NoteCreate, locale: str | None = None
    ) -> note.Note:
        record = self._repository.create(db, note_in)
        return self._to_note(record, locale or note_in.default_locale)

    def update_note(
        self,
        db: Session,
        note_db: models.Note,
        note_in: note.NoteUpdate,
        locale: str | None = None,
    ) -> note.Note:
        record = self._repository.update(db, note_db, note_in)
        return self._to_note(record, locale or record.default_locale)

    def delete_note(self, db: Session, note_db: models.Note) -> None:
        self._repository.delete(db, note_db)

    def get_feed(
        self, db: Session, user_id: str, locale: str, limit: int = 100
    ) -> note.NoteFeed:
        records = self._repository.get_all(db, user_id=user_id, limit=limit)
        summaries = [self._to_summary(item, locale) for item in records]
        sections = self._build_sections(summaries)
        return note.NoteFeed(entries=summaries, sections=sections)

    def search_notes(
        self,
        db: Session,
        user_id: str,
        locale: str,
        query: str,
        limit: int = 50,
    ) -> list[note.NoteSummary]:
        records = self._repository.search(db, user_id=user_id, query=query, limit=limit)
        return [self._to_summary(item, locale) for item in records]

    def _to_note(self, model: models.Note, locale: str) -> note.Note:
        translation = self._select_translation(model.translations, locale, model.default_locale)
        title = (translation.title if translation else model.title) or 'Untitled note'
        preview = translation.preview if translation else model.preview
        content = translation.content if translation else model.content

        category = self._to_schema_category(model.category)
        created_at = self._coerce_datetime(model.created_at)
        updated_at = self._coerce_optional_datetime(model.updated_at)
        date = self._coerce_datetime(model.date or model.created_at)
        attachments = [self._to_attachment(item) for item in model.attachments]
        tags = [link.tag.name for link in model.tag_links if link.tag is not None]

        return note.Note(
            id=model.id,
            user_id=model.user_id,
            title=title,
            preview=preview,
            content=content,
            date=date,
            category=category,
            has_attachment=bool(model.has_attachment),
            progress_percent=float(model.progress_percent)
            if model.progress_percent is not None
            else None,
            default_locale=model.default_locale,
            created_at=created_at,
            updated_at=updated_at,
            translations=[
                note.NoteTranslation(
                    locale=item.locale,
                    title=item.title,
                    preview=item.preview,
                    content=item.content,
                    created_at=self._coerce_optional_datetime(item.created_at),
                    updated_at=self._coerce_optional_datetime(item.updated_at),
                )
                for item in model.translations
            ],
            attachments=attachments,
            tags=tags,
        )

    def _to_summary(self, model: models.Note, locale: str) -> note.NoteSummary:
        translation = self._select_translation(model.translations, locale, model.default_locale)
        title = (translation.title if translation else model.title) or 'Untitled note'
        preview = translation.preview if translation else model.preview
        content = translation.content if translation else model.content
        date = self._coerce_datetime(model.date or model.created_at)
        category = self._to_schema_category(model.category)
        progress = float(model.progress_percent) if model.progress_percent is not None else None
        tags = [link.tag.name for link in model.tag_links if link.tag is not None]

        return note.NoteSummary(
            id=model.id,
            user_id=model.user_id,
            title=title,
            preview=preview,
            content=content,
            date=date,
            category=category,
            has_attachment=bool(model.has_attachment),
            progress_percent=progress,
            tags=tags,
        )

    def _build_sections(self, summaries: list[note.NoteSummary]) -> list[note.NoteSection]:
        grouped: dict[datetime, list[note.NoteSummary]] = defaultdict(list)
        for summary in summaries:
            key = self._normalise_month(summary.date)
            grouped[key].append(summary)

        sections: list[note.NoteSection] = []
        for index, month in enumerate(sorted(grouped.keys(), reverse=True)):
            notes_sorted = sorted(grouped[month], key=lambda item: item.date, reverse=True)
            label = 'This Month' if index == 0 else month.strftime('%B %Y')
            sections.append(note.NoteSection(label=label, date=month, notes=notes_sorted))
        return sections

    def _select_translation(
        self,
        translations: Iterable[models.NoteTranslation],
        locale: str,
        default_locale: str,
    ) -> models.NoteTranslation | None:
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

    def _to_schema_category(self, value: models.NoteCategory | None) -> note.NoteCategory:
        if isinstance(value, models.NoteCategory):
            raw = value.value
        else:
            raw = str(value or '').lower()
        try:
            return note.NoteCategory(raw)
        except ValueError:
            return note.NoteCategory.journal

    def _normalise_month(self, value: datetime) -> datetime:
        naive = value.replace(tzinfo=None)
        return naive.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    def _coerce_datetime(self, value: datetime | None) -> datetime:
        if value is None:
            return datetime.utcnow().replace(tzinfo=None)
        return value.replace(tzinfo=None)

    def _coerce_optional_datetime(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return value.replace(tzinfo=None)

    def _to_attachment(self, model: models.NoteAttachment) -> note.NoteAttachment:
        return note.NoteAttachment(
            id=model.id,
            file_name=model.file_name,
            file_url=model.file_url,
            mime_type=model.mime_type,
            size_bytes=model.size_bytes,
            created_at=self._coerce_optional_datetime(model.created_at),
        )





