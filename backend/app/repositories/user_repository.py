from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from .. import models
from ..schemas import user


class UserRepository:
    def get(self, db: Session, user_id: str) -> models.User | None:
        return db.query(models.User).filter(models.User.id == user_id).first()

    def get_by_email(self, db: Session, email: str) -> models.User | None:
        return db.query(models.User).filter(models.User.email == email).first()

    def list(self, db: Session, skip: int = 0, limit: int = 100) -> list[models.User]:
        return (
            db.query(models.User)
            .order_by(models.User.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def create(self, db: Session, user_in: user.UserCreate, password_hash: str) -> models.User:
        user_id = str(uuid.uuid4())
        display_name = (
            user_in.display_name.strip()
            if isinstance(user_in.display_name, str) and user_in.display_name.strip()
            else None
        )
        db_user = models.User(
            id=user_id,
            email=user_in.email,
            password_hash=password_hash,
            display_name=display_name,
            preferred_locale=user_in.preferred_locale,
            avatar_url=user_in.avatar_url,
            theme_preference=user_in.theme_preference,
        )
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user

    def update(
        self,
        db: Session,
        user_db: models.User,
        user_in: user.UserUpdate,
        password_hash: str | None = None,
    ) -> models.User:
        update_fields = user_in.model_dump(exclude_none=True, exclude={'password'})
        if 'display_name' in update_fields:
            value = update_fields['display_name']
            if isinstance(value, str):
                update_fields['display_name'] = value.strip() or None
        for key, value in update_fields.items():
            setattr(user_db, key, value)
        if password_hash is not None:
            user_db.password_hash = password_hash
        db.add(user_db)
        db.commit()
        db.refresh(user_db)
        return user_db

    def delete(self, db: Session, user_db: models.User) -> None:
        db.delete(user_db)
        db.commit()

    def touch_last_active(self, db: Session, user_db: models.User) -> models.User:
        user_db.last_active_at = datetime.now(timezone.utc)
        db.add(user_db)
        db.commit()
        db.refresh(user_db)
        return user_db
