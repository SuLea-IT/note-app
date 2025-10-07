from __future__ import annotations

from typing import Iterable

from sqlalchemy.orm import Session, selectinload

from .. import models


class DiaryTemplateRepository:
    def list(self, db: Session) -> list[models.DiaryTemplate]:
        return (
            db.query(models.DiaryTemplate)
            .options(selectinload(models.DiaryTemplate.translations))
            .order_by(models.DiaryTemplate.id.asc())
            .all()
        )


def select_translation(
    translations: Iterable[models.DiaryTemplateTranslation],
    preferences: list[str],
    default_locale: str,
) -> models.DiaryTemplateTranslation | None:
    items = list(translations)
    if not items:
        return None

    candidates: list[str] = []
    for value in preferences:
        norm = value.lower()
        if norm not in candidates:
            candidates.append(norm)
    default_norm = (default_locale or '').lower()
    if default_norm and default_norm not in candidates:
        candidates.append(default_norm)

    for target in candidates:
        for item in items:
            if (item.locale or '').lower() == target and item.title:
                return item
    return items[0]
