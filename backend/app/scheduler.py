from __future__ import annotations

import logging
from datetime import timezone
from typing import Optional

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from .config import get_settings
from .services.notification_service import NotificationService

logger = logging.getLogger(__name__)

_scheduler: Optional[AsyncIOScheduler] = None
_service: Optional[NotificationService] = None


def start_scheduler(service: NotificationService | None = None) -> None:
    global _scheduler, _service
    if _scheduler is not None:
        return

    settings = get_settings()
    _service = service or NotificationService()

    interval_seconds = max(settings.notification_poll_interval_seconds, 15)
    trigger = IntervalTrigger(seconds=interval_seconds)

    scheduler = AsyncIOScheduler(timezone=timezone.utc)
    scheduler.add_job(
        _service.run_due_reminders,
        trigger=trigger,
        id='dispatch_task_reminders',
        replace_existing=True,
        max_instances=1,
        coalesce=True,
        misfire_grace_time=interval_seconds,
    )

    scheduler.start()
    _scheduler = scheduler
    logger.info(
        'Notification scheduler started with interval %s seconds',
        interval_seconds,
    )


def shutdown_scheduler() -> None:
    global _scheduler
    if _scheduler is None:
        return
    _scheduler.shutdown(wait=False)
    _scheduler = None
    logger.info('Notification scheduler stopped')


def get_notification_service() -> NotificationService:
    global _service
    if _service is None:
        _service = NotificationService()
    return _service

