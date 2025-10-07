from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models
from ..repositories.user_repository import UserRepository
from ..schemas import auth, user
from ..security import TokenPair
from .habit_service import HabitService


class UserService:
    def __init__(self, repository: UserRepository | None = None) -> None:
        self._repository = repository or UserRepository()

    def get_user_model(self, db: Session, user_id: str) -> models.User | None:
        return self._repository.get(db, user_id)

    def list_users(
        self, db: Session, skip: int = 0, limit: int = 100
    ) -> list[user.User]:
        records = self._repository.list(db, skip=skip, limit=limit)
        return [self._to_schema(item) for item in records]

    def get_user(self, db: Session, user_id: str) -> user.User | None:
        record = self._repository.get(db, user_id)
        if record is None:
            return None
        return self._to_schema(record)

    def get_profile(self, db: Session, user_id: str) -> user.UserProfile | None:
        record = self._repository.get(db, user_id)
        if record is None:
            return None
        base_schema = self._to_schema(record)
        statistics = self._build_statistics(db, record)
        return user.UserProfile(**base_schema.model_dump(), statistics=statistics)

    def create_user(self, db: Session, payload: user.UserCreate) -> user.User:
        existing = self._repository.get_by_email(db, payload.email)
        if existing is not None:
            raise ValueError('email_already_registered')

        salt = uuid.uuid4().hex
        password_hash = self._hash_password(payload.password, salt)
        record = self._repository.create(db, payload, password_hash=password_hash)
        return self._to_schema(record)

    def update_user(
        self, db: Session, user_db: models.User, payload: user.UserUpdate
    ) -> user.User:
        password_hash: str | None = None
        if payload.password is not None:
            salt = uuid.uuid4().hex
            password_hash = self._hash_password(payload.password, salt)
        record = self._repository.update(
            db, user_db=user_db, user_in=payload, password_hash=password_hash
        )
        return self._to_schema(record)

    def delete_user(self, db: Session, user_db: models.User) -> None:
        self._repository.delete(db, user_db=user_db)

    def touch_last_active(self, db: Session, user_db: models.User) -> user.User:
        refreshed = self._repository.touch_last_active(db, user_db)
        return self._to_schema(refreshed)

    def verify_credentials(
        self, db: Session, email: str, password: str
    ) -> user.User | None:
        record = self._repository.get_by_email(db, email)
        if record is None:
            return None
        if not self._check_password(password, record.password_hash):
            return None
        refreshed = self._repository.touch_last_active(db, record)
        return self._to_schema(refreshed)

    def build_auth_session(
        self, user_payload: user.User, token_pair: TokenPair
    ) -> auth.AuthSession:
        return auth.AuthSession(
            user=user_payload,
            tokens=auth.TokenPayload(
                access_token=token_pair.access.token,
                refresh_token=token_pair.refresh.token,
                expires_at=self._make_naive(token_pair.access.expires_at),
                refresh_expires_at=self._make_naive(token_pair.refresh.expires_at),
            ),
        )

    def _hash_password(self, password: str, salt: str) -> str:
        digest = hashlib.sha256(f'{salt}:{password}'.encode('utf-8')).hexdigest()
        return f'{salt}${digest}'

    def _check_password(self, password: str, encoded: str) -> bool:
        if '$' not in encoded:
            return False
        salt, hashed = encoded.split('$', 1)
        digest = hashlib.sha256(f'{salt}:{password}'.encode('utf-8')).hexdigest()
        return digest == hashed

    def _to_schema(self, record: models.User) -> user.User:
        return user.User(
            id=record.id,
            email=record.email,
            display_name=record.display_name,
            preferred_locale=record.preferred_locale,
            avatar_url=record.avatar_url,
            theme_preference=record.theme_preference,
            created_at=record.created_at,
            updated_at=record.updated_at,
            last_active_at=record.last_active_at,
        )

    def _make_naive(self, dt: datetime) -> datetime:
        return dt.replace(tzinfo=None)

    def _build_statistics(
        self,
        db: Session,
        user_db: models.User,
    ) -> user.UserStatistics:
        user_id = user_db.id

        note_count = (
            db.query(func.count(models.Note.id))
            .filter(models.Note.user_id == user_id)
            .scalar()
            or 0
        )

        diary_count = (
            db.query(func.count(models.Diary.id))
            .filter(models.Diary.user_id == user_id)
            .scalar()
            or 0
        )

        habit_count = (
            db.query(func.count(models.Habit.id))
            .filter(models.Habit.user_id == user_id)
            .scalar()
            or 0
        )

        habit_streak = 0
        if habit_count:
            habit_service = HabitService()
            feed = habit_service.get_feed(
                db=db,
                user_id=user_id,
                locale=user_db.preferred_locale,
            )
            habit_streak = feed.overview.completed_streak

        activity_candidates: list[datetime | None] = [
            user_db.last_active_at,
            self._max_timestamp(
                db,
                models.Note.updated_at,
                models.Note.created_at,
                models.Note.user_id == user_id,
            ),
            self._max_timestamp(
                db,
                models.Diary.updated_at,
                models.Diary.created_at,
                models.Diary.user_id == user_id,
            ),
            self._max_timestamp(
                db,
                models.Habit.updated_at,
                models.Habit.created_at,
                models.Habit.user_id == user_id,
            ),
        ]
        last_active = self._latest(activity_candidates)

        return user.UserStatistics(
            note_count=int(note_count),
            diary_count=int(diary_count),
            habit_count=int(habit_count),
            habit_streak=int(habit_streak),
            last_active_at=last_active,
        )

    def _max_timestamp(
        self,
        db: Session,
        updated_column,
        created_column,
        *filters,
    ) -> datetime | None:
        value = (
            db.query(func.max(func.coalesce(updated_column, created_column)))
            .filter(*filters)
            .scalar()
        )
        return self._ensure_timezone(value)

    def _latest(self, values: list[datetime | None]) -> datetime | None:
        normalized: list[datetime] = []
        for value in values:
            if value is None:
                continue
            ensured = self._ensure_timezone(value)
            if ensured is not None:
                normalized.append(ensured)
        if not normalized:
            return None
        return max(normalized)

    def _ensure_timezone(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
