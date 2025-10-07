from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class NoteCategory(str, Enum):
    diary = 'diary'
    checklist = 'checklist'
    idea = 'idea'
    journal = 'journal'
    reminder = 'reminder'


class NoteTranslationPayload(BaseModel):
    locale: str = Field(..., min_length=2, max_length=32)
    title: str
    preview: str | None = None
    content: str | None = None


class NoteBase(BaseModel):
    title: str
    preview: str | None = None
    date: datetime
    category: NoteCategory
    has_attachment: bool = False
    progress_percent: float | None = None
    content: str | None = None


class NoteSummary(NoteBase):
    id: str
    user_id: str
    tags: list[str] = Field(default_factory=list)


class NoteSection(BaseModel):
    label: str
    date: datetime
    notes: list[NoteSummary]


class NoteFeed(BaseModel):
    entries: list[NoteSummary]
    sections: list[NoteSection]


class NoteCreate(NoteBase):
    user_id: str
    default_locale: str = Field(default='en-US', min_length=2, max_length=32)
    translations: list[NoteTranslationPayload] | None = None
    attachments: list['NoteAttachmentPayload'] | None = None
    tags: list[str] | None = None


class NoteUpdate(NoteBase):
    default_locale: str | None = Field(default=None, min_length=2, max_length=32)
    translations: list[NoteTranslationPayload] | None = None
    attachments: list['NoteAttachmentPayload'] | None = None
    tags: list[str] | None = None


class NoteTranslation(NoteTranslationPayload):
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class Note(NoteBase):
    id: str
    user_id: str
    default_locale: str
    created_at: datetime
    updated_at: datetime | None = None
    translations: list[NoteTranslation] = Field(default_factory=list)
    attachments: list['NoteAttachment'] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class NoteAttachmentPayload(BaseModel):
    id: str | None = None
    file_name: str = Field(..., min_length=1, max_length=255)
    file_url: str = Field(..., min_length=1, max_length=1024)
    mime_type: str | None = Field(default=None, max_length=255)
    size_bytes: int | None = Field(default=None, ge=0)


class NoteAttachment(NoteAttachmentPayload):
    id: str
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


NoteCreate.model_rebuild()
NoteUpdate.model_rebuild()
Note.model_rebuild()
