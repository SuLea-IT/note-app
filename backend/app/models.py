import enum

from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    Time,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from .database import Base


class DiaryCategory(enum.Enum):
    diary = 'diary'
    checklist = 'checklist'
    idea = 'idea'
    journal = 'journal'
    reminder = 'reminder'


class HabitStatus(enum.Enum):
    upcoming = 'upcoming'
    in_progress = 'in_progress'
    completed = 'completed'


class NoteCategory(enum.Enum):
    diary = 'diary'
    checklist = 'checklist'
    idea = 'idea'
    journal = 'journal'
    reminder = 'reminder'


class AudioNoteStatus(enum.Enum):
    pending = 'pending'
    processing = 'processing'
    completed = 'completed'
    failed = 'failed'


class TaskPriority(enum.Enum):
    low = 'low'
    normal = 'normal'
    high = 'high'
    urgent = 'urgent'


class TaskStatus(enum.Enum):
    pending = 'pending'
    in_progress = 'in_progress'
    completed = 'completed'
    cancelled = 'cancelled'


class TaskAssociationType(enum.Enum):
    note = 'note'
    diary = 'diary'


class NotificationChannel(enum.Enum):
    push = 'push'
    local = 'local'
    email = 'email'


class TaskReminderRepeat(enum.Enum):
    none = 'none'
    daily = 'daily'
    weekly = 'weekly'
    monthly = 'monthly'


class User(Base):
    __tablename__ = 'users'

    id = Column(String(255), primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    display_name = Column(String(255), nullable=True)
    preferred_locale = Column(String(32), nullable=False, default='en-US')
    avatar_url = Column(String(512), nullable=True)
    theme_preference = Column(String(64), nullable=True)
    last_active_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    notes = relationship('Note', back_populates='user', cascade='all, delete-orphan')
    diaries = relationship('Diary', back_populates='user', cascade='all, delete-orphan')
    habits = relationship('Habit', back_populates='user', cascade='all, delete-orphan')
    tasks = relationship('Task', back_populates='user', cascade='all, delete-orphan')
    task_tags = relationship('TaskTag', back_populates='user', cascade='all, delete-orphan')
    audio_notes = relationship('AudioNote', back_populates='user', cascade='all, delete-orphan')
    devices = relationship('UserDevice', back_populates='user', cascade='all, delete-orphan')


class UserDevice(Base):
    __tablename__ = 'user_devices'
    __table_args__ = (UniqueConstraint('device_token', name='uq_user_device_token'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        String(255),
        ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    device_token = Column(String(1024), nullable=False)
    platform = Column(String(32), nullable=False)
    channels = Column(Text, nullable=False, default='push', server_default='push')
    locale = Column(String(32), nullable=True)
    timezone = Column(String(64), nullable=False, default='UTC', server_default='UTC')
    app_version = Column(String(32), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, server_default='1')
    last_seen_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship('User', back_populates='devices')


class Habit(Base):
    __tablename__ = 'habits'

    id = Column(String(255), primary_key=True, index=True)
    user_id = Column(String(255), ForeignKey('users.id', ondelete='CASCADE'), index=True, nullable=False)
    title = Column(String(255), index=True)
    description = Column(String(1024), nullable=True)
    time_label = Column(String(255), nullable=True)
    status = Column(Enum(HabitStatus))
    reminder_time = Column(Time(timezone=False), nullable=True)
    repeat_rule = Column(String(64), nullable=True)
    accent_color = Column(BigInteger, nullable=True, default=0xFF7C4DFF)
    default_locale = Column(String(32), nullable=False, default='en-US')
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship('User', back_populates='habits')
    translations = relationship(
        'HabitTranslation', back_populates='habit', cascade='all, delete-orphan'
    )
    entries = relationship(
        'HabitEntry',
        back_populates='habit',
        cascade='all, delete-orphan',
        order_by='desc(HabitEntry.entry_date)',
    )


class QuickAction(Base):
    __tablename__ = 'quick_actions'

    id = Column(String(255), primary_key=True, index=True)
    icon = Column(String(255), nullable=True)
    order_index = Column(Integer, default=0, nullable=False)
    background_color = Column(BigInteger, nullable=False, default=0xFFFFFFFF)
    foreground_color = Column(BigInteger, nullable=False, default=0xFF000000)
    default_title = Column(String(255), nullable=False, default='')
    default_subtitle = Column(String(255), nullable=False, default='')
    default_locale = Column(String(32), nullable=False, default='en')
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    translations = relationship(
        'QuickActionTranslation',
        back_populates='action',
        cascade='all, delete-orphan',
    )


class Diary(Base):
    __tablename__ = 'diaries'

    id = Column(String(255), primary_key=True, index=True)
    user_id = Column(String(255), ForeignKey('users.id', ondelete='CASCADE'), index=True, nullable=False)
    title = Column(String(255), index=True)
    preview = Column(String(1024), nullable=True)
    content = Column(Text, nullable=True)
    date = Column(DateTime(timezone=True))
    category = Column(Enum(DiaryCategory))
    has_attachment = Column(Boolean, default=False)
    progress_percent = Column(Float, default=0.0)
    weather = Column(String(255), nullable=True)
    mood = Column(String(64), nullable=True)
    tags = Column(Text, nullable=True)
    can_share = Column(Boolean, default=False)
    template_id = Column(String(255), nullable=True)
    default_locale = Column(String(32), nullable=False, default='en-US')
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship('User', back_populates='diaries')
    translations = relationship(
        'DiaryTranslation', back_populates='diary', cascade='all, delete-orphan'
    )
    attachments = relationship(
        'DiaryAttachment',
        back_populates='diary',
        cascade='all, delete-orphan',
        order_by='DiaryAttachment.created_at',
    )
    shares = relationship(
        'DiaryShare',
        back_populates='diary',
        cascade='all, delete-orphan',
        uselist=False,
    )


class Note(Base):
    __tablename__ = 'notes'

    id = Column(String(255), primary_key=True, index=True)
    user_id = Column(String(255), ForeignKey('users.id', ondelete='CASCADE'), index=True, nullable=False)
    title = Column(String(255), index=True)
    preview = Column(String(1024), nullable=True)
    content = Column(Text, nullable=True)
    date = Column(DateTime(timezone=True))
    category = Column(Enum(NoteCategory))
    has_attachment = Column(Boolean, default=False)
    progress_percent = Column(Float, default=0.0)
    default_locale = Column(String(32), nullable=False, default='en-US')
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship('User', back_populates='notes')
    translations = relationship(
        'NoteTranslation', back_populates='note', cascade='all, delete-orphan'
    )
    attachments = relationship(
        'NoteAttachment',
        back_populates='note',
        cascade='all, delete-orphan',
        order_by='NoteAttachment.created_at',
    )
    tag_links = relationship(
        'NoteTagLink',
        back_populates='note',
        cascade='all, delete-orphan',
    )


class NoteTranslation(Base):
    __tablename__ = 'note_translations'
    __table_args__ = (UniqueConstraint('note_id', 'locale', name='uq_note_translation_locale'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    note_id = Column(String(255), ForeignKey('notes.id', ondelete='CASCADE'), nullable=False)
    locale = Column(String(32), nullable=False)
    title = Column(String(255), nullable=False)
    preview = Column(String(1024), nullable=True)
    content = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    note = relationship('Note', back_populates='translations')


class NoteAttachment(Base):
    __tablename__ = 'note_attachments'

    id = Column(String(255), primary_key=True)
    note_id = Column(String(255), ForeignKey('notes.id', ondelete='CASCADE'), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_url = Column(String(1024), nullable=False)
    mime_type = Column(String(255), nullable=True)
    size_bytes = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    note = relationship('Note', back_populates='attachments')


class NoteTag(Base):
    __tablename__ = 'note_tags'
    __table_args__ = (UniqueConstraint('user_id', 'name', name='uq_note_tag_user_name'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(255), ForeignKey('users.id', ondelete='CASCADE'), index=True, nullable=False)
    name = Column(String(64), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship('User')
    links = relationship(
        'NoteTagLink',
        back_populates='tag',
        cascade='all, delete-orphan',
    )


class NoteTagLink(Base):
    __tablename__ = 'note_tag_links'
    __table_args__ = (UniqueConstraint('note_id', 'tag_id', name='uq_note_tag_link'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    note_id = Column(String(255), ForeignKey('notes.id', ondelete='CASCADE'), nullable=False)
    tag_id = Column(Integer, ForeignKey('note_tags.id', ondelete='CASCADE'), nullable=False)

    note = relationship('Note', back_populates='tag_links')
    tag = relationship('NoteTag', back_populates='links')


class DiaryTranslation(Base):
    __tablename__ = 'diary_translations'
    __table_args__ = (UniqueConstraint('diary_id', 'locale', name='uq_diary_translation_locale'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    diary_id = Column(String(255), ForeignKey('diaries.id', ondelete='CASCADE'), nullable=False)
    locale = Column(String(32), nullable=False)
    title = Column(String(255), nullable=False)
    preview = Column(String(1024), nullable=True)
    content = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    diary = relationship('Diary', back_populates='translations')


class DiaryAttachment(Base):
    __tablename__ = 'diary_attachments'

    id = Column(String(255), primary_key=True)
    diary_id = Column(String(255), ForeignKey('diaries.id', ondelete='CASCADE'), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_url = Column(String(1024), nullable=False)
    mime_type = Column(String(255), nullable=True)
    size_bytes = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    diary = relationship('Diary', back_populates='attachments')


class DiaryShare(Base):
    __tablename__ = 'diary_shares'

    id = Column(String(255), primary_key=True, index=True)
    diary_id = Column(
        String(255),
        ForeignKey('diaries.id', ondelete='CASCADE'),
        nullable=False,
        unique=True,
    )
    share_code = Column(String(64), unique=True, nullable=False)
    share_url = Column(String(1024), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    diary = relationship('Diary', back_populates='shares')


class HabitTranslation(Base):
    __tablename__ = 'habit_translations'
    __table_args__ = (UniqueConstraint('habit_id', 'locale', name='uq_habit_translation_locale'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    habit_id = Column(String(255), ForeignKey('habits.id', ondelete='CASCADE'), nullable=False)
    locale = Column(String(32), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(String(1024), nullable=True)
    time_label = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    habit = relationship('Habit', back_populates='translations')


class HabitEntry(Base):
    __tablename__ = 'habit_entries'
    __table_args__ = (
        UniqueConstraint('habit_id', 'entry_date', name='uq_habit_entry_unique_day'),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    habit_id = Column(
        String(255),
        ForeignKey('habits.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    entry_date = Column(Date, nullable=False)
    status = Column(Enum(HabitStatus), nullable=False, default=HabitStatus.completed)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    duration_minutes = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    habit = relationship('Habit', back_populates='entries')


class QuickActionTranslation(Base):
    __tablename__ = 'quick_action_translations'
    __table_args__ = (
        UniqueConstraint('action_id', 'locale', name='uq_quick_action_translation_locale'),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    action_id = Column(String(255), ForeignKey('quick_actions.id', ondelete='CASCADE'), nullable=False)
    locale = Column(String(32), nullable=False)
    title = Column(String(255), nullable=False)
    subtitle = Column(String(255), nullable=False, default='')
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    action = relationship('QuickAction', back_populates='translations')


class Task(Base):
    __tablename__ = 'tasks'

    id = Column(String(255), primary_key=True, index=True)
    user_id = Column(String(255), ForeignKey('users.id', ondelete='CASCADE'), index=True, nullable=False)
    title = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=True)
    due_at = Column(DateTime(timezone=True), nullable=True, index=True)
    all_day = Column(Boolean, default=False)
    priority = Column(Enum(TaskPriority), nullable=False, default=TaskPriority.normal)
    status = Column(Enum(TaskStatus), nullable=False, default=TaskStatus.pending, index=True)
    order_index = Column(Integer, nullable=True, default=0)
    related_entity_id = Column(String(255), nullable=True)
    related_entity_type = Column(Enum(TaskAssociationType), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    completed_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship('User', back_populates='tasks')
    reminders = relationship(
        'TaskReminder',
        back_populates='task',
        cascade='all, delete-orphan',
        order_by='TaskReminder.remind_at',
    )
    tag_links = relationship(
        'TaskTagLink',
        back_populates='task',
        cascade='all, delete-orphan',
    )


class TaskReminder(Base):
    __tablename__ = 'task_reminders'

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_id = Column(String(255), ForeignKey('tasks.id', ondelete='CASCADE'), nullable=False, index=True)
    remind_at = Column(DateTime(timezone=True), nullable=False)
    timezone = Column(String(64), nullable=False, default='UTC', server_default='UTC')
    channel = Column(
        Enum(NotificationChannel),
        nullable=False,
        default=NotificationChannel.push,
        server_default=NotificationChannel.push.value,
    )
    repeat_rule = Column(
        Enum(TaskReminderRepeat),
        nullable=False,
        default=TaskReminderRepeat.none,
        server_default=TaskReminderRepeat.none.value,
    )
    repeat_every = Column(Integer, nullable=False, default=1, server_default='1')
    active = Column(Boolean, nullable=False, default=True, server_default='1')
    last_triggered_at = Column(DateTime(timezone=True), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    task = relationship('Task', back_populates='reminders')


class TaskTag(Base):
    __tablename__ = 'task_tags'
    __table_args__ = (UniqueConstraint('user_id', 'name', name='uq_task_tag_user_name'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(255), ForeignKey('users.id', ondelete='CASCADE'), index=True, nullable=False)
    name = Column(String(64), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship('User', back_populates='task_tags')
    links = relationship(
        'TaskTagLink',
        back_populates='tag',
        cascade='all, delete-orphan',
    )


class TaskTagLink(Base):
    __tablename__ = 'task_tag_links'
    __table_args__ = (UniqueConstraint('task_id', 'tag_id', name='uq_task_tag_link'),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_id = Column(String(255), ForeignKey('tasks.id', ondelete='CASCADE'), nullable=False, index=True)
    tag_id = Column(Integer, ForeignKey('task_tags.id', ondelete='CASCADE'), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    task = relationship('Task', back_populates='tag_links')
    tag = relationship('TaskTag', back_populates='links')


class AudioNote(Base):
    __tablename__ = 'audio_notes'

    id = Column(String(255), primary_key=True, index=True)
    user_id = Column(String(255), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    file_url = Column(String(1024), nullable=False)
    mime_type = Column(String(128), nullable=False, default='audio/mpeg')
    size_bytes = Column(BigInteger, nullable=True)
    duration_seconds = Column(Float, nullable=True)
    transcription_status = Column(Enum(AudioNoteStatus), nullable=False, default=AudioNoteStatus.pending, index=True)
    transcription_text = Column(Text, nullable=True)
    transcription_language = Column(String(32), nullable=True)
    transcription_updated_at = Column(DateTime(timezone=True), nullable=True)
    transcription_error = Column(String(512), nullable=True)
    recorded_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship('User', back_populates='audio_notes')


class DiaryTemplate(Base):
    __tablename__ = 'diary_templates'

    id = Column(String(255), primary_key=True, index=True)
    icon = Column(String(255), nullable=True)
    accent_color = Column(BigInteger, nullable=False, default=0xFFFF8B3D)
    default_title = Column(String(255), nullable=False, default='')
    default_subtitle = Column(String(255), nullable=False, default='')
    default_locale = Column(String(32), nullable=False, default='en')
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    translations = relationship(
        'DiaryTemplateTranslation',
        back_populates='template',
        cascade='all, delete-orphan',
    )


class DiaryTemplateTranslation(Base):
    __tablename__ = 'diary_template_translations'
    __table_args__ = (
        UniqueConstraint('template_id', 'locale', name='uq_diary_template_translation_locale'),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    template_id = Column(String(255), ForeignKey('diary_templates.id', ondelete='CASCADE'), nullable=False)
    locale = Column(String(32), nullable=False)
    title = Column(String(255), nullable=False)
    subtitle = Column(String(255), nullable=False, default='')
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    template = relationship('DiaryTemplate', back_populates='translations')
