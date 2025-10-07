from __future__ import annotations

from datetime import datetime, timezone
from typing import Iterable

from sqlalchemy.orm import Session

from .. import models
from ..repositories.audio_note_repository import AudioNoteRepository
from ..schemas import audio_note as audio_schema


class AudioNoteService:
    def __init__(self, repository: AudioNoteRepository | None = None) -> None:
        self._repository = repository or AudioNoteRepository()

    def get_audio_note_model(
        self, db: Session, note_id: str
    ) -> models.AudioNote | None:
        return self._repository.get(db, note_id)

    def get_audio_note(
        self, db: Session, note_id: str
    ) -> audio_schema.AudioNote | None:
        record = self._repository.get(db, note_id)
        if record is None:
            return None
        return self._to_schema(record)

    def list_audio_notes(
        self,
        db: Session,
        *,
        user_id: str,
        statuses: Iterable[audio_schema.AudioNoteStatus] | None = None,
        search: str | None = None,
        skip: int = 0,
        limit: int = 50,
    ) -> audio_schema.AudioNoteCollection:
        mapped_statuses = (
            {models.AudioNoteStatus(status.value) for status in statuses}
            if statuses
            else None
        )
        records, total = self._repository.list(
            db,
            user_id=user_id,
            statuses=mapped_statuses,
            search=search,
            skip=skip,
            limit=limit,
        )
        items = [self._to_schema(record) for record in records]
        return audio_schema.AudioNoteCollection(total=total, items=items)

    def create_audio_note(
        self,
        db: Session,
        payload: audio_schema.AudioNoteCreate,
    ) -> audio_schema.AudioNote:
        record = self._repository.create(db, payload)
        return self._to_schema(record)

    def update_audio_note(
        self,
        db: Session,
        *,
        note_db: models.AudioNote,
        payload: audio_schema.AudioNoteUpdate,
    ) -> audio_schema.AudioNote:
        record = self._repository.update(db, note_db=note_db, payload=payload)
        return self._to_schema(record)

    def update_transcription(
        self,
        db: Session,
        *,
        note_db: models.AudioNote,
        payload: audio_schema.AudioNoteTranscriptionUpdate,
    ) -> audio_schema.AudioNote:
        record = self._repository.update_transcription(db, note_db=note_db, payload=payload)
        return self._to_schema(record)

    def delete_audio_note(self, db: Session, note_db: models.AudioNote) -> None:
        self._repository.delete(db, note_db)

    def _to_schema(self, model: models.AudioNote) -> audio_schema.AudioNote:
        status = audio_schema.AudioNoteStatus(model.transcription_status.value)
        return audio_schema.AudioNote(
            id=model.id,
            user_id=model.user_id,
            title=model.title,
            description=model.description,
            file_url=model.file_url,
            mime_type=model.mime_type,
            size_bytes=model.size_bytes,
            duration_seconds=float(model.duration_seconds) if model.duration_seconds is not None else None,
            transcription_status=status,
            transcription_text=model.transcription_text,
            transcription_language=model.transcription_language,
            transcription_error=model.transcription_error,
            recorded_at=self._coerce_optional_datetime(model.recorded_at),
            created_at=self._coerce_datetime(model.created_at),
            updated_at=self._coerce_optional_datetime(model.updated_at),
            transcription_updated_at=self._coerce_optional_datetime(model.transcription_updated_at),
        )

    def _coerce_datetime(self, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value

    def _coerce_optional_datetime(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return self._coerce_datetime(value)

