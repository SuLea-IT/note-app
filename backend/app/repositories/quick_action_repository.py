from __future__ import annotations

from sqlalchemy.orm import Session, selectinload

from .. import models


class QuickActionRepository:
    def list(self, db: Session) -> list[models.QuickAction]:
        return (
            db.query(models.QuickAction)
            .options(selectinload(models.QuickAction.translations))
            .order_by(models.QuickAction.order_index.asc(), models.QuickAction.id.asc())
            .all()
        )
