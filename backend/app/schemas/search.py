from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional, Union

from pydantic import BaseModel, Field


class SearchResultType(str, Enum):
    note = 'note'
    diary = 'diary'
    task = 'task'
    habit = 'habit'
    audio_note = 'audio_note'


class SearchResult(BaseModel):
    id: str
    type: SearchResultType
    title: str
    excerpt: str | None = None
    date: datetime | None = None
    tags: list[str] = Field(default_factory=list)
    metadata: Dict[str, Union[str, int, float, bool, None]] = Field(default_factory=dict)


class SearchSection(BaseModel):
    type: SearchResultType
    label: str
    results: List[SearchResult]


class SearchResponse(BaseModel):
    query: str
    total: int
    results: List[SearchResult]
    sections: List[SearchSection]

