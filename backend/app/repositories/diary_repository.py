from __future__ import annotations

import json
import uuid
from datetime import datetime
from typing import Sequence

from sqlalchemy import func, or_
from sqlalchemy.orm import Session, selectinload

from .. import models
from ..schemas import diary


def _dump_tags(tags: Sequence[str] | None) -> str | None:
    if not tags:
        return None
    return json.dumps(list(tags))


class DiaryRepository:
    def get(self, db: Session, diary_id: str) -> models.Diary | None:
        return (
            db.query(models.Diary)
            .options(
                selectinload(models.Diary.translations),
                selectinload(models.Diary.attachments),
                selectinload(models.Diary.shares),
            )
            .filter(models.Diary.id == diary_id)
            .first()
        )

    def get_all(
        self, db: Session, user_id: str | None = None, skip: int = 0, limit: int = 100
    ) -> list[models.Diary]:
        query = db.query(models.Diary).options(
            selectinload(models.Diary.translations),
            selectinload(models.Diary.attachments),
            selectinload(models.Diary.shares),
        )
        if user_id is not None:
            query = query.filter(models.Diary.user_id == user_id)
        return query.order_by(models.Diary.date.desc()).offset(skip).limit(limit).all()

    def search(
        self,
        db: Session,
        *,
        user_id: str,
        query: str,
        limit: int = 50,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> list[models.Diary]:
        term = f"%{query.lower()}%"
        stmt = (
            db.query(models.Diary)
            .options(
                selectinload(models.Diary.translations),
                selectinload(models.Diary.attachments),
                selectinload(models.Diary.shares),
            )
            .filter(models.Diary.user_id == user_id)
        )

        if start_date is not None:
            stmt = stmt.filter(models.Diary.date >= start_date)
        if end_date is not None:
            stmt = stmt.filter(models.Diary.date <= end_date)

        stmt = stmt.filter(
            or_(
                func.lower(models.Diary.title).like(term),
                func.lower(models.Diary.preview).like(term),
                func.lower(models.Diary.content).like(term),
                func.lower(models.Diary.tags).like(term),
                func.lower(models.Diary.weather).like(term),
                func.lower(models.Diary.mood).like(term),
            )
        )

        return stmt.order_by(models.Diary.date.desc()).limit(limit).all()

    def create(self, db: Session, diary_in: diary.DiaryCreate) -> models.Diary:
        diary_id = str(uuid.uuid4())
        category_value = diary_in.category.value if diary_in.category else models.DiaryCategory.journal.value
        db_diary = models.Diary(
            id=diary_id,
            user_id=diary_in.user_id,
            title=diary_in.title,
            preview=diary_in.preview,
            content=diary_in.content,
            date=diary_in.date,
            category=models.DiaryCategory(category_value),
            has_attachment=diary_in.has_attachment,
            progress_percent=diary_in.progress_percent or 0.0,
            weather=diary_in.weather,
            mood=diary_in.mood,
            tags=_dump_tags(diary_in.tags),
            can_share=diary_in.can_share,
            template_id=diary_in.template_id,
            default_locale=diary_in.default_locale,
        )

        translations = list(diary_in.translations or [])
        locales = {item.locale for item in translations}
        if diary_in.default_locale not in locales:
            translations.append(
                diary.DiaryTranslationPayload(
                    locale=diary_in.default_locale,
                    title=diary_in.title,
                    preview=diary_in.preview,
                    content=diary_in.content,
                )
            )

        for payload in translations:
            db_diary.translations.append(
                models.DiaryTranslation(
                    locale=payload.locale,
                    title=payload.title,
                    preview=payload.preview,
                    content=payload.content,
                )
            )

        self._sync_attachments(
            db,
            diary_db=db_diary,
            payloads=diary_in.attachments or [],
        )
        db_diary.has_attachment = bool(db_diary.attachments)

        db.add(db_diary)
        db.commit()
        db.refresh(db_diary)
        return db_diary

    def update(
        self, db: Session, diary_db: models.Diary, diary_in: diary.DiaryUpdate
    ) -> models.Diary:
        update_fields = diary_in.model_dump(exclude={'translations'}, exclude_none=True)

        if 'category' in update_fields:
            update_fields['category'] = models.DiaryCategory(update_fields['category'].value)
        if 'tags' in update_fields:
            update_fields['tags'] = _dump_tags(update_fields['tags'])

        for key, value in update_fields.items():
            setattr(diary_db, key, value)

        if diary_in.translations is not None:
            existing = {item.locale: item for item in diary_db.translations}
            for payload in diary_in.translations:
                translation = existing.get(payload.locale)
                if translation is None:
                    translation = models.DiaryTranslation(
                        locale=payload.locale,
                        title=payload.title,
                        preview=payload.preview,
                        content=payload.content,
                    )
                    diary_db.translations.append(translation)
                else:
                    translation.title = payload.title
                    translation.preview = payload.preview
                    translation.content = payload.content

        if diary_in.attachments is not None:
            self._sync_attachments(db, diary_db=diary_db, payloads=diary_in.attachments)
        diary_db.has_attachment = bool(diary_db.attachments)

        db.add(diary_db)
        db.commit()
        db.refresh(diary_db)
        return diary_db

    def delete(self, db: Session, diary_db: models.Diary) -> models.Diary:
        db.delete(diary_db)
        db.commit()
        return diary_db

    def _sync_attachments(
        self,
        db: Session,
        *,
        diary_db: models.Diary,
        payloads: list[diary.DiaryAttachmentPayload],
    ) -> None:
        existing = {attachment.id: attachment for attachment in diary_db.attachments}
        retained: set[str] = set()

        for payload in payloads:
            attachment_id = payload.id or str(uuid.uuid4())
            retained.add(attachment_id)
            attachment = existing.get(attachment_id)
            if attachment is None:
                attachment = models.DiaryAttachment(
                    id=attachment_id,
                    diary_id=diary_db.id,
                )
                diary_db.attachments.append(attachment)
            attachment.file_name = payload.file_name
            attachment.file_url = payload.file_url
            attachment.mime_type = payload.mime_type
            attachment.size_bytes = payload.size_bytes

        for attachment in list(diary_db.attachments):
            if attachment.id not in retained:
                diary_db.attachments.remove(attachment)
                db.delete(attachment)
