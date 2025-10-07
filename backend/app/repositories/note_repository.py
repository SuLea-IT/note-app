from __future__ import annotations

import uuid

from sqlalchemy import func, or_
from sqlalchemy.orm import Session, selectinload

from .. import models
from ..schemas import note


class NoteRepository:
    def get(self, db: Session, note_id: str) -> models.Note | None:
        return (
            db.query(models.Note)
            .options(
                selectinload(models.Note.translations),
                selectinload(models.Note.attachments),
                selectinload(models.Note.tag_links).selectinload(models.NoteTagLink.tag),
            )
            .filter(models.Note.id == note_id)
            .first()
        )

    def get_all(
        self, db: Session, user_id: str | None = None, skip: int = 0, limit: int = 100
    ) -> list[models.Note]:
        query = db.query(models.Note).options(
            selectinload(models.Note.translations),
            selectinload(models.Note.attachments),
            selectinload(models.Note.tag_links).selectinload(models.NoteTagLink.tag),
        )
        if user_id is not None:
            query = query.filter(models.Note.user_id == user_id)
        return query.order_by(models.Note.date.desc()).offset(skip).limit(limit).all()

    def create(self, db: Session, note_in: note.NoteCreate) -> models.Note:
        note_id = str(uuid.uuid4())
        db_note = models.Note(
            id=note_id,
            user_id=note_in.user_id,
            title=note_in.title,
            preview=note_in.preview,
            content=note_in.content,
            date=note_in.date,
            category=models.NoteCategory(note_in.category.value),
            has_attachment=note_in.has_attachment,
            progress_percent=note_in.progress_percent or 0.0,
            default_locale=note_in.default_locale,
        )

        translations = list(note_in.translations or [])
        locales = {item.locale for item in translations}
        if note_in.default_locale not in locales:
            translations.append(
                note.NoteTranslationPayload(
                    locale=note_in.default_locale,
                    title=note_in.title,
                    preview=note_in.preview,
                    content=note_in.content,
                )
            )

        for payload in translations:
            db_note.translations.append(
                models.NoteTranslation(
                    locale=payload.locale,
                    title=payload.title,
                    preview=payload.preview,
                    content=payload.content,
                )
            )

        self._sync_attachments(
            db,
            note_db=db_note,
            payloads=note_in.attachments or [],
        )
        self._sync_tags(
            db,
            note_db=db_note,
            user_id=note_in.user_id,
            tags=note_in.tags or [],
        )
        db_note.has_attachment = bool(db_note.attachments)

        db.add(db_note)
        db.commit()
        db.refresh(db_note)
        return db_note

    def update(
        self, db: Session, note_db: models.Note, note_in: note.NoteUpdate
    ) -> models.Note:
        update_fields = note_in.model_dump(exclude={'translations', 'attachments', 'tags'}, exclude_none=True)

        if 'category' in update_fields:
            update_fields['category'] = models.NoteCategory(update_fields['category'].value)

        for key, value in update_fields.items():
            setattr(note_db, key, value)

        if note_in.translations is not None:
            existing = {item.locale: item for item in note_db.translations}
            for payload in note_in.translations:
                translation = existing.get(payload.locale)
                if translation is None:
                    translation = models.NoteTranslation(
                        locale=payload.locale,
                        title=payload.title,
                        preview=payload.preview,
                        content=payload.content,
                    )
                    note_db.translations.append(translation)
                else:
                    translation.title = payload.title
                    translation.preview = payload.preview
                    translation.content = payload.content

        if note_in.attachments is not None:
            self._sync_attachments(db, note_db=note_db, payloads=note_in.attachments)

        if note_in.tags is not None:
            self._sync_tags(db, note_db=note_db, user_id=note_db.user_id, tags=note_in.tags)

        note_db.has_attachment = bool(note_db.attachments)

        db.add(note_db)
        db.commit()
        db.refresh(note_db)
        return note_db

    def delete(self, db: Session, note_db: models.Note) -> models.Note:
        db.delete(note_db)
        db.commit()
        return note_db

    def search(
        self,
        db: Session,
        user_id: str,
        query: str,
        limit: int = 50,
    ) -> list[models.Note]:
        term = f"%{query.lower()}%"
        return (
            db.query(models.Note)
            .options(
                selectinload(models.Note.translations),
                selectinload(models.Note.attachments),
                selectinload(models.Note.tag_links).selectinload(models.NoteTagLink.tag),
            )
            .filter(models.Note.user_id == user_id)
            .filter(
                or_(
                    func.lower(models.Note.title).like(term),
                    func.lower(models.Note.preview).like(term),
                    func.lower(models.Note.content).like(term),
                )
            )
            .order_by(models.Note.date.desc())
            .limit(limit)
            .all()
        )

    def _sync_attachments(
        self,
        db: Session,
        *,
        note_db: models.Note,
        payloads: list[note.NoteAttachmentPayload],
    ) -> None:
        existing = {attachment.id: attachment for attachment in note_db.attachments}
        retained: set[str] = set()

        for payload in payloads:
            attachment_id = payload.id or str(uuid.uuid4())
            retained.add(attachment_id)
            attachment = existing.get(attachment_id)
            if attachment is None:
                attachment = models.NoteAttachment(
                    id=attachment_id,
                    note_id=note_db.id,
                )
                note_db.attachments.append(attachment)
            attachment.file_name = payload.file_name
            attachment.file_url = payload.file_url
            attachment.mime_type = payload.mime_type
            attachment.size_bytes = payload.size_bytes

        for attachment in list(note_db.attachments):
            if attachment.id not in retained:
                note_db.attachments.remove(attachment)
                db.delete(attachment)

    def _sync_tags(
        self,
        db: Session,
        *,
        note_db: models.Note,
        user_id: str,
        tags: list[str],
    ) -> None:
        normalized = {tag.strip() for tag in tags if tag and tag.strip()}
        existing_links = list(note_db.tag_links)
        existing_names = {link.tag.name for link in existing_links}

        # remove tags no longer present
        for link in existing_links:
            if link.tag.name not in normalized:
                note_db.tag_links.remove(link)
                db.delete(link)

        if not normalized:
            return

        remaining = {link.tag.name for link in note_db.tag_links}
        pending = normalized - remaining
        if not pending:
            return

        query = (
            db.query(models.NoteTag)
            .filter(models.NoteTag.user_id == user_id)
            .filter(models.NoteTag.name.in_(pending))
        )
        found = {tag.name: tag for tag in query.all()}

        for name in pending:
            tag = found.get(name)
            if tag is None:
                tag = models.NoteTag(user_id=user_id, name=name)
                db.add(tag)
                db.flush()
            note_db.tag_links.append(models.NoteTagLink(tag=tag))
