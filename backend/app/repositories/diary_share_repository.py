from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy.orm import Session

from .. import models
from ..config import get_settings


class DiaryShareRepository:
    def __init__(self, *, base_url: str | None = None) -> None:
        settings = get_settings()
        self._base_url = base_url or settings.share_base_url

    def upsert(
        self,
        db: Session,
        diary_db: models.Diary,
        *,
        expires_at: datetime | None = None,
    ) -> models.DiaryShare:
        share = (
            db.query(models.DiaryShare)
            .filter(models.DiaryShare.diary_id == diary_db.id)
            .one_or_none()
        )

        share_code = self._generate_unique_code(db)
        share_url = self._build_share_url(share_code)

        if share is None:
            share = models.DiaryShare(
                id=str(uuid.uuid4()),
                diary_id=diary_db.id,
                share_code=share_code,
                share_url=share_url,
                expires_at=expires_at,
            )
            db.add(share)
        else:
            share.share_code = share_code
            share.share_url = share_url
            share.expires_at = expires_at
            db.add(share)

        db.commit()
        db.refresh(share)
        return share

    def get_by_diary(self, db: Session, diary_id: str) -> models.DiaryShare | None:
        return (
            db.query(models.DiaryShare)
            .filter(models.DiaryShare.diary_id == diary_id)
            .one_or_none()
        )

    def _generate_unique_code(self, db: Session) -> str:
        for _ in range(8):
            code = uuid.uuid4().hex[:12]
            exists = (
                db.query(models.DiaryShare)
                .filter(models.DiaryShare.share_code == code)
                .one_or_none()
            )
            if exists is None:
                return code
        raise RuntimeError('Unable to allocate unique diary share code')

    def _build_share_url(self, code: str) -> str:
        base = self._base_url.rstrip('/')
        return f'{base}/{code}'
