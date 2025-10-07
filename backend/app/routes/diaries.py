from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import schemas
from ..database import SessionLocal
from ..services.diary_service import DiaryService

router = APIRouter(prefix='/diaries', tags=['diaries'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> DiaryService:
    return DiaryService()


@router.get('/feed', response_model=schemas.diary.DiaryFeed)
def read_diary_feed(
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: DiaryService = Depends(get_service),
) -> schemas.diary.DiaryFeed:
    return service.get_feed(db=db, user_id=user_id, locale=lang)


@router.post('/', response_model=schemas.diary.Diary)
@router.post('', response_model=schemas.diary.Diary)
def create_diary(
    diary_in: schemas.diary.DiaryCreate,
    lang: str = Query('en-US', description='Preferred locale for response'),
    db: Session = Depends(get_db),
    service: DiaryService = Depends(get_service),
) -> schemas.diary.Diary:
    return service.create_diary(db=db, diary_in=diary_in, locale=lang)


@router.get('/', response_model=list[schemas.diary.Diary])
@router.get('', response_model=list[schemas.diary.Diary])
def read_diaries(
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    service: DiaryService = Depends(get_service),
) -> list[schemas.diary.Diary]:
    return service.get_all_diaries(
        db=db, user_id=user_id, locale=lang, skip=skip, limit=limit
    )


@router.get('/{diary_id}', response_model=schemas.diary.Diary)
def read_diary(
    diary_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: DiaryService = Depends(get_service),
) -> schemas.diary.Diary:
    record = service.get_diary(db=db, diary_id=diary_id, locale=lang)
    if record is None or record.user_id != user_id:
        raise HTTPException(status_code=404, detail='Diary not found')
    return record


@router.put('/{diary_id}', response_model=schemas.diary.Diary)
def update_diary(
    diary_id: str,
    diary_in: schemas.diary.DiaryUpdate,
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: DiaryService = Depends(get_service),
) -> schemas.diary.Diary:
    diary_db = service.get_diary_model(db=db, diary_id=diary_id)
    if diary_db is None or diary_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Diary not found')
    return service.update_diary(db=db, diary_db=diary_db, diary_in=diary_in, locale=lang)


@router.delete('/{diary_id}', status_code=204)
def delete_diary(
    diary_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: DiaryService = Depends(get_service),
) -> None:
    diary_db = service.get_diary_model(db=db, diary_id=diary_id)
    if diary_db is None or diary_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Diary not found')
    service.delete_diary(db=db, diary_db=diary_db)


@router.post('/{diary_id}/share', response_model=schemas.diary.DiaryShareInfo)
def share_diary(
    diary_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    expires_in_hours: int | None = Query(
        None,
        ge=1,
        le=24 * 30,
        description='Optional share lifetime in hours',
    ),
    db: Session = Depends(get_db),
    service: DiaryService = Depends(get_service),
) -> schemas.diary.DiaryShareInfo:
    diary_db = service.get_diary_model(db=db, diary_id=diary_id)
    if diary_db is None or diary_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Diary not found')

    try:
        return service.create_share(
            db=db,
            diary_db=diary_db,
            expires_in_hours=expires_in_hours,
        )
    except ValueError as exc:  # sharing disabled
        raise HTTPException(status_code=400, detail=str(exc)) from exc
