from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class DiaryCategory(str, Enum):
    diary = 'diary'
    checklist = 'checklist'
    idea = 'idea'
    journal = 'journal'
    reminder = 'reminder'


class DiaryTranslationPayload(BaseModel):
    locale: str = Field(..., min_length=2, max_length=32)
    title: str
    preview: str | None = None
    content: str | None = None


class DiaryBase(BaseModel):
    title: str
    preview: str | None = None
    content: str | None = None
    date: datetime = Field(default_factory=datetime.utcnow)
    category: DiaryCategory = DiaryCategory.journal
    has_attachment: bool = False
    progress_percent: float | None = None
    weather: str | None = None
    mood: str | None = None
    tags: list[str] = Field(default_factory=list)
    can_share: bool = False
    template_id: str | None = None


class DiarySummary(DiaryBase):
    id: str
    user_id: str
    attachments: list['DiaryAttachment'] = Field(default_factory=list)
    share: DiaryShareInfo | None = None


class DiarySection(BaseModel):
    label: str
    date: datetime
    diaries: list[DiarySummary]


class DiaryTemplate(BaseModel):
    id: str
    title: str
    subtitle: str
    accent_color: int


class DiaryFeed(BaseModel):
    entries: list[DiarySummary]
    templates: list[DiaryTemplate]


class DiaryCreate(DiaryBase):
    user_id: str
    default_locale: str = Field(default='en-US', min_length=2, max_length=32)
    translations: list[DiaryTranslationPayload] | None = None
    attachments: list['DiaryAttachmentPayload'] | None = None


class DiaryUpdate(DiaryBase):
    default_locale: str | None = Field(default=None, min_length=2, max_length=32)
    translations: list[DiaryTranslationPayload] | None = None
    attachments: list['DiaryAttachmentPayload'] | None = None


class DiaryShareInfo(BaseModel):
    share_id: str
    share_url: str
    created_at: datetime | None = None
    expires_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class DiaryTranslation(DiaryTranslationPayload):
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class Diary(DiaryBase):
    id: str
    user_id: str
    default_locale: str
    created_at: datetime
    updated_at: datetime | None = None
    translations: list[DiaryTranslation] = Field(default_factory=list)
    attachments: list['DiaryAttachment'] = Field(default_factory=list)
    share: DiaryShareInfo | None = None

    model_config = ConfigDict(from_attributes=True)


class DiaryAttachmentPayload(BaseModel):
    id: str | None = None
    file_name: str = Field(..., min_length=1, max_length=255)
    file_url: str = Field(..., min_length=1, max_length=1024)
    mime_type: str | None = Field(default=None, max_length=255)
    size_bytes: int | None = Field(default=None, ge=0)


class DiaryAttachment(DiaryAttachmentPayload):
    id: str
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


DiaryCreate.model_rebuild()
DiaryUpdate.model_rebuild()
Diary.model_rebuild()
