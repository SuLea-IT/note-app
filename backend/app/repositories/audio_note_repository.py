from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Iterable

from sqlalchemy import or_
from sqlalchemy.orm import Session

from .. import models
from ..schemas import audio_note as audio_schema


class AudioNoteRepository:
    def get(self, db: Session, note_id: str) -> models.AudioNote | None:
        return (
            db.query(models.AudioNote)
            .filter(models.AudioNote.id == note_id)
            .first()
        )

    def list(
        self,
        db: Session,
        *,
        user_id: str,
        statuses: Iterable[models.AudioNoteStatus] | None = None,
        search: str | None = None,
        skip: int = 0,
        limit: int = 50,
    ) -> tuple[list[models.AudioNote], int]:
        query = db.query(models.AudioNote).filter(models.AudioNote.user_id == user_id)

        if statuses:
            query = query.filter(models.AudioNote.transcription_status.in_(tuple(statuses)))

        if search:
            pattern = f'%{search.strip()}%'
            query = query.filter(
                or_(
                    models.AudioNote.title.ilike(pattern),
                    models.AudioNote.description.ilike(pattern),
                )
            )

        total = query.count()

        records = (
            query.order_by(models.AudioNote.created_at.desc())
            .offset(max(skip, 0))
            .limit(max(limit, 1))
            .all()
        )
        return records, int(total)

    def create(
        self,
        db: Session,
        payload: audio_schema.AudioNoteCreate,
    ) -> models.AudioNote:
        note_id = str(uuid.uuid4())
        status = models.AudioNoteStatus(payload.transcription_status.value)
        now = datetime.now(timezone.utc)

        db_note = models.AudioNote(
            id=note_id,
            user_id=payload.user_id,
            title=payload.title,
            description=payload.description,
            file_url=str(payload.file_url),
            mime_type=payload.mime_type,
            size_bytes=payload.size_bytes,
            duration_seconds=payload.duration_seconds,
            transcription_status=status,
            transcription_text=payload.transcription_text,
            transcription_language=payload.transcription_language,
            transcription_error=payload.transcription_error,
            transcription_updated_at=now if payload.transcription_text is not None else None,
            recorded_at=payload.recorded_at,
        )

        db.add(db_note)
        db.commit()
        db.refresh(db_note)
        return db_note

    def update(
        self,
        db: Session,
        *,
        note_db: models.AudioNote,
        payload: audio_schema.AudioNoteUpdate,
    ) -> models.AudioNote:
        update_fields = payload.model_dump(exclude_none=True)
        if 'transcription_status' in update_fields:
            update_fields['transcription_status'] = models.AudioNoteStatus(
                update_fields['transcription_status'].value
            )

        if 'recorded_at' in update_fields and update_fields['recorded_at'] is None:
            note_db.recorded_at = None

        for key, value in update_fields.items():
            if key == 'transcription_status':
                note_db.transcription_status = value
            elif key == 'transcription_text':
                note_db.transcription_text = value
                note_db.transcription_updated_at = datetime.now(timezone.utc)
            elif key == 'transcription_language':
                note_db.transcription_language = value
            elif key == 'transcription_error':
                note_db.transcription_error = value
            elif key == 'title':
                note_db.title = value
            elif key == 'description':
                note_db.description = value
            elif key == 'recorded_at':
                note_db.recorded_at = value

        db.add(note_db)
        db.commit()
        db.refresh(note_db)
        return note_db

    def update_transcription(
        self,
        db: Session,
        *,
        note_db: models.AudioNote,
        payload: audio_schema.AudioNoteTranscriptionUpdate,
    ) -> models.AudioNote:
        note_db.transcription_status = models.AudioNoteStatus(
            payload.transcription_status.value
        )
        note_db.transcription_text = payload.transcription_text
        note_db.transcription_language = payload.transcription_language
        note_db.transcription_error = payload.transcription_error
        note_db.transcription_updated_at = datetime.now(timezone.utc)

        db.add(note_db)
        db.commit()
        db.refresh(note_db)
        return note_db

    def delete(self, db: Session, note_db: models.AudioNote) -> None:
        db.delete(note_db)
        db.commit()

