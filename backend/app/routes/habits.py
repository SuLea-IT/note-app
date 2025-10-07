from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import schemas
from ..database import SessionLocal
from ..services.habit_service import HabitService

router = APIRouter(prefix='/habits', tags=['habits'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> HabitService:
    return HabitService()


@router.get('/feed', response_model=schemas.habit.HabitFeed)
def read_habit_feed(
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: HabitService = Depends(get_service),
) -> schemas.habit.HabitFeed:
    return service.get_feed(db=db, user_id=user_id, locale=lang)


@router.post('/', response_model=schemas.habit.Habit)
@router.post('', response_model=schemas.habit.Habit)
def create_habit(
    habit_in: schemas.habit.HabitCreate,
    lang: str = Query('en-US', description='Preferred locale for response'),
    db: Session = Depends(get_db),
    service: HabitService = Depends(get_service),
) -> schemas.habit.Habit:
    return service.create_habit(db=db, habit_in=habit_in, locale=lang)


@router.get('/', response_model=list[schemas.habit.Habit])
@router.get('', response_model=list[schemas.habit.Habit])
def read_habits(
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    service: HabitService = Depends(get_service),
) -> list[schemas.habit.Habit]:
    return service.get_all_habits(
        db=db, user_id=user_id, locale=lang, skip=skip, limit=limit
    )


@router.get('/{habit_id}', response_model=schemas.habit.Habit)
def read_habit(
    habit_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: HabitService = Depends(get_service),
) -> schemas.habit.Habit:
    record = service.get_habit(db=db, habit_id=habit_id, locale=lang)
    if record is None or record.user_id != user_id:
        raise HTTPException(status_code=404, detail='Habit not found')
    return record


@router.put('/{habit_id}', response_model=schemas.habit.Habit)
def update_habit(
    habit_id: str,
    habit_in: schemas.habit.HabitUpdate,
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: HabitService = Depends(get_service),
) -> schemas.habit.Habit:
    habit_db = service.get_habit_model(db=db, habit_id=habit_id)
    if habit_db is None or habit_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Habit not found')
    return service.update_habit(db=db, habit_db=habit_db, habit_in=habit_in, locale=lang)


@router.delete('/{habit_id}', status_code=204)
def delete_habit(
    habit_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: HabitService = Depends(get_service),
) -> None:
    habit_db = service.get_habit_model(db=db, habit_id=habit_id)
    if habit_db is None or habit_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Habit not found')
    service.delete_habit(db=db, habit_db=habit_db)
