from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class AudioNoteStatus(str, Enum):
    pending = 'pending'
    processing = 'processing'
    completed = 'completed'
    failed = 'failed'


class AudioNoteBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    file_url: HttpUrl
    mime_type: str = Field(default='audio/mpeg', max_length=128)
    size_bytes: int | None = Field(default=None, ge=0)
    duration_seconds: float | None = Field(default=None, ge=0)
    transcription_status: AudioNoteStatus = AudioNoteStatus.pending
    transcription_text: str | None = None
    transcription_language: str | None = Field(default=None, max_length=32)
    transcription_error: str | None = Field(default=None, max_length=512)
    recorded_at: datetime | None = None


class AudioNoteCreate(AudioNoteBase):
    user_id: str = Field(..., min_length=1, max_length=255)


class AudioNoteUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    transcription_status: AudioNoteStatus | None = None
    transcription_text: str | None = None
    transcription_language: str | None = Field(default=None, max_length=32)
    transcription_error: str | None = Field(default=None, max_length=512)
    recorded_at: datetime | None = None


class AudioNoteTranscriptionUpdate(BaseModel):
    transcription_status: AudioNoteStatus
    transcription_text: str | None = None
    transcription_language: str | None = Field(default=None, max_length=32)
    transcription_error: str | None = Field(default=None, max_length=512)


class AudioNote(AudioNoteBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime | None = None
    transcription_updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class AudioNoteCollection(BaseModel):
    total: int
    items: list[AudioNote]

