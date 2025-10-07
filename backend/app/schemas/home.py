from pydantic import BaseModel

from .note import NoteSection
from .task import TaskStatistics


class QuickAction(BaseModel):
    id: str
    title: str
    subtitle: str
    background_color: int
    foreground_color: int
    icon: str | None = None


class HomeHabit(BaseModel):
    id: str
    label: str
    time_range: str
    notes: str
    is_completed: bool


class HomeFeed(BaseModel):
    sections: list[NoteSection]
    quick_actions: list[QuickAction]
    habits: list[HomeHabit]
    tasks: TaskStatistics
