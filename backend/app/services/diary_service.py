from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Iterable

from sqlalchemy.orm import Session

from .. import models
from ..repositories.diary_repository import DiaryRepository
from ..repositories.diary_share_repository import DiaryShareRepository
from ..repositories.diary_template_repository import (
    DiaryTemplateRepository,
    select_translation as select_template_translation,
)
from ..schemas import diary


class DiaryService:
    def __init__(
        self,
        repository: DiaryRepository | None = None,
        template_repository: DiaryTemplateRepository | None = None,
        share_repository: DiaryShareRepository | None = None,
    ) -> None:
        self._repository = repository or DiaryRepository()
        self._template_repository = template_repository or DiaryTemplateRepository()
        self._share_repository = share_repository or DiaryShareRepository()

    def get_diary_model(self, db: Session, diary_id: str) -> models.Diary | None:
        return self._repository.get(db, diary_id)

    def get_diary(
        self, db: Session, diary_id: str, locale: str | None = None
    ) -> diary.Diary | None:
        record = self._repository.get(db, diary_id)
        if record is None:
            return None
        return self._to_diary(record, locale or record.default_locale)

    def get_all_diaries(
        self,
        db: Session,
        user_id: str,
        locale: str,
        skip: int = 0,
        limit: int = 100,
    ) -> list[diary.Diary]:
        records = self._repository.get_all(
            db, user_id=user_id, skip=skip, limit=limit
        )
        return [self._to_diary(item, locale) for item in records]

    def create_diary(
        self, db: Session, diary_in: diary.DiaryCreate, locale: str | None = None
    ) -> diary.Diary:
        record = self._repository.create(db, diary_in)
        return self._to_diary(record, locale or diary_in.default_locale)

    def update_diary(
        self,
        db: Session,
        diary_db: models.Diary,
        diary_in: diary.DiaryUpdate,
        locale: str | None = None,
    ) -> diary.Diary:
        record = self._repository.update(db, diary_db, diary_in)
        return self._to_diary(record, locale or record.default_locale)

    def delete_diary(self, db: Session, diary_db: models.Diary) -> None:
        self._repository.delete(db, diary_db)

    def get_feed(
        self, db: Session, user_id: str, locale: str, limit: int = 100
    ) -> diary.DiaryFeed:
        records = self._repository.get_all(db, user_id=user_id, limit=limit)
        entries = [self._to_summary(item, locale) for item in records]
        templates = self._load_templates(db, locale)
        return diary.DiaryFeed(entries=entries, templates=templates)

    def search_diaries(
        self,
        db: Session,
        *,
        user_id: str,
        locale: str,
        query: str,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        limit: int = 50,
    ) -> list[diary.DiarySummary]:
        records = self._repository.search(
            db,
            user_id=user_id,
            query=query,
            start_date=start_date,
            end_date=end_date,
            limit=limit,
        )
        return [self._to_summary(item, locale) for item in records]

    def create_share(
        self,
        db: Session,
        diary_db: models.Diary,
        *,
        expires_in_hours: int | None = None,
    ) -> diary.DiaryShareInfo:
        if not diary_db.can_share:
            raise ValueError('Sharing disabled for this diary')

        expires_at: datetime | None = None
        if expires_in_hours is not None and expires_in_hours > 0:
            expires_at = datetime.utcnow() + timedelta(hours=expires_in_hours)

        share = self._share_repository.upsert(
            db,
            diary_db=diary_db,
            expires_at=expires_at,
        )
        return self._to_share_info(share)

    def _to_diary(self, model: models.Diary, locale: str) -> diary.Diary:
        translation = self._select_translation(model.translations, locale, model.default_locale)
        title = (translation.title if translation else model.title) or 'Untitled diary'
        preview = translation.preview if translation else model.preview
        content = translation.content if translation else model.content
        category = self._to_schema_category(model.category)
        tags = self._parse_tags(model.tags)

        return diary.Diary(
            id=model.id,
            user_id=model.user_id,
            title=title,
            preview=preview,
            content=content,
            date=self._coerce_datetime(model.date or model.created_at),
            category=category,
            has_attachment=bool(model.has_attachment),
            progress_percent=float(model.progress_percent)
            if model.progress_percent is not None
            else None,
            weather=model.weather,
            mood=model.mood,
            tags=tags,
            can_share=bool(model.can_share),
            template_id=model.template_id,
            default_locale=model.default_locale,
            created_at=self._coerce_datetime(model.created_at),
            updated_at=self._coerce_optional_datetime(model.updated_at),
            share=self._to_share_info(model.shares) if model.shares else None,
            translations=[
                diary.DiaryTranslation(
                    locale=item.locale,
                    title=item.title,
                    preview=item.preview,
                    content=item.content,
                    created_at=self._coerce_optional_datetime(item.created_at),
                    updated_at=self._coerce_optional_datetime(item.updated_at),
                )
                for item in model.translations
            ],
            attachments=[
                diary.DiaryAttachment(
                    id=attachment.id,
                    file_name=attachment.file_name,
                    file_url=attachment.file_url,
                    mime_type=attachment.mime_type,
                    size_bytes=attachment.size_bytes,
                    created_at=self._coerce_optional_datetime(attachment.created_at),
                )
                for attachment in model.attachments
            ],
        )

    def _to_summary(self, model: models.Diary, locale: str) -> diary.DiarySummary:
        translation = self._select_translation(model.translations, locale, model.default_locale)
        title = (translation.title if translation else model.title) or 'Untitled diary'
        preview = translation.preview if translation else model.preview
        content = translation.content if translation else model.content
        category = self._to_schema_category(model.category)
        tags = self._parse_tags(model.tags)

        return diary.DiarySummary(
            id=model.id,
            user_id=model.user_id,
            title=title,
            preview=preview,
            content=content,
            date=self._coerce_datetime(model.date or model.created_at),
            category=category,
            has_attachment=bool(model.has_attachment),
            progress_percent=float(model.progress_percent)
            if model.progress_percent is not None
            else None,
            weather=model.weather,
            mood=model.mood,
            tags=tags,
            can_share=bool(model.can_share),
            template_id=model.template_id,
            attachments=[
                diary.DiaryAttachment(
                    id=item.id,
                    file_name=item.file_name,
                    file_url=item.file_url,
                    mime_type=item.mime_type,
                    size_bytes=item.size_bytes,
                    created_at=self._coerce_optional_datetime(item.created_at),
                )
                for item in model.attachments
            ],
            share=self._to_share_info(model.shares) if model.shares else None,
        )

    def _load_templates(self, db: Session, locale: str) -> list[diary.DiaryTemplate]:
        records = self._template_repository.list(db)
        if not records:
            return []

        preferences = self._locale_preferences(locale)
        templates: list[diary.DiaryTemplate] = []
        for record in records:
            translation = select_template_translation(
                record.translations,
                preferences,
                record.default_locale,
            )
            title = (translation.title if translation else record.default_title) or record.id
            subtitle = (translation.subtitle if translation else record.default_subtitle) or ''
            templates.append(
                diary.DiaryTemplate(
                    id=record.id,
                    title=title,
                    subtitle=subtitle,
                    accent_color=record.accent_color,
                )
            )
        return templates

    def _parse_tags(self, raw: str | None) -> list[str]:
        if not raw:
            return []
        try:
            decoded = json.loads(raw)
        except json.JSONDecodeError:
            return []
        if isinstance(decoded, list):
            return [str(item) for item in decoded]
        return []

    def _select_translation(
        self,
        translations: Iterable[models.DiaryTranslation],
        locale: str,
        default_locale: str,
    ) -> models.DiaryTranslation | None:
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

    def _locale_preferences(self, requested: str, default: str | None = None) -> list[str]:
        preferences: list[str] = []
        for value in (requested, default or ''):
            if not value:
                continue
            norm = value.lower()
            if norm not in preferences:
                preferences.append(norm)
            primary = norm.split('-')[0]
            if primary and primary not in preferences:
                preferences.append(primary)
        return preferences

    def _to_schema_category(self, value: models.DiaryCategory | None) -> diary.DiaryCategory:
        if isinstance(value, models.DiaryCategory):
            raw = value.value
        else:
            raw = str(value or '').lower()
        try:
            return diary.DiaryCategory(raw)
        except ValueError:
            return diary.DiaryCategory.journal

    def _coerce_datetime(self, value: datetime | None) -> datetime:
        if value is None:
            return datetime.utcnow().replace(tzinfo=None)
        return value.replace(tzinfo=None)

    def _coerce_optional_datetime(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return value.replace(tzinfo=None)

    def _to_share_info(self, share: models.DiaryShare) -> diary.DiaryShareInfo:
        return diary.DiaryShareInfo(
            share_id=share.id,
            share_url=share.share_url,
            expires_at=self._coerce_optional_datetime(share.expires_at),
            created_at=self._coerce_optional_datetime(share.created_at),
        )





