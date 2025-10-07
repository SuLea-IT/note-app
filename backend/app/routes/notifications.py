from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..schemas import notification as notification_schema
from ..scheduler import get_notification_service
from ..services.notification_service import NotificationService

router = APIRouter(prefix='/notifications', tags=['notifications'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> NotificationService:
    return get_notification_service()


@router.post('/devices', response_model=notification_schema.Device, status_code=201)
def register_device(
    payload: notification_schema.DeviceRegistration,
    db: Session = Depends(get_db),
    service: NotificationService = Depends(get_service),
) -> notification_schema.Device:
    return service.register_device(db, payload)


@router.get('/devices', response_model=notification_schema.DeviceCollection)
def list_devices(
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: NotificationService = Depends(get_service),
) -> notification_schema.DeviceCollection:
    return service.list_devices(db, user_id=user_id)


@router.patch('/devices/{device_token}', response_model=notification_schema.Device)
def update_device(
    device_token: str,
    payload: notification_schema.DevicePreferenceUpdate,
    user_id: str = Query(..., description='Owner user identifier'),
    db: Session = Depends(get_db),
    service: NotificationService = Depends(get_service),
) -> notification_schema.Device:
    device = service.update_device(
        db,
        user_id=user_id,
        device_token=device_token,
        update=payload,
    )
    if device is None:
        raise HTTPException(status_code=404, detail='Device not found')
    return device


@router.delete('/devices/{device_token}', status_code=204)
def remove_device(
    device_token: str,
    db: Session = Depends(get_db),
    service: NotificationService = Depends(get_service),
) -> None:
    service.remove_device(db, device_token=device_token)


@router.post('/dispatch', response_model=dict[str, int])
def trigger_dispatch(
    db: Session = Depends(get_db),
    service: NotificationService = Depends(get_service),
) -> dict[str, int]:
    count = service.dispatch_due_reminders(db)
    return {'dispatched': count}
