from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserBase(BaseModel):
    email: EmailStr
    display_name: str | None = None
    preferred_locale: str = Field(default='en-US', min_length=2, max_length=32)
    avatar_url: str | None = Field(default=None, max_length=512)
    theme_preference: str | None = Field(default=None, max_length=64)


class UserCreate(UserBase):
    password: str = Field(..., min_length=6)


class UserUpdate(BaseModel):
    display_name: str | None = None
    preferred_locale: str | None = Field(default=None, min_length=2, max_length=32)
    password: str | None = Field(default=None, min_length=6)
    avatar_url: str | None = Field(default=None, max_length=512)
    theme_preference: str | None = Field(default=None, max_length=64)


class UserCredentials(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)


class User(UserBase):
    id: str
    created_at: datetime
    updated_at: datetime | None = None
    last_active_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class UserStatistics(BaseModel):
    note_count: int
    diary_count: int
    habit_count: int
    habit_streak: int
    last_active_at: datetime | None = None


class UserProfile(User):
    statistics: UserStatistics
