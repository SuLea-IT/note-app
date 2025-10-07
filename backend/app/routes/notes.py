from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import schemas
from ..database import SessionLocal
from ..services.note_service import NoteService

router = APIRouter(prefix='/notes', tags=['notes'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> NoteService:
    return NoteService()


@router.get('/feed', response_model=schemas.note.NoteFeed)
def read_note_feed(
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: NoteService = Depends(get_service),
) -> schemas.note.NoteFeed:
    return service.get_feed(db=db, user_id=user_id, locale=lang)


@router.post('/', response_model=schemas.note.Note)
def create_note(
    note_in: schemas.note.NoteCreate,
    lang: str = Query('en-US', description='Preferred locale for response'),
    db: Session = Depends(get_db),
    service: NoteService = Depends(get_service),
) -> schemas.note.Note:
    return service.create_note(db=db, note_in=note_in, locale=lang)


@router.get('/', response_model=list[schemas.note.Note])
def read_notes(
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    service: NoteService = Depends(get_service),
) -> list[schemas.note.Note]:
    return service.get_all_notes(
        db=db, user_id=user_id, locale=lang, skip=skip, limit=limit
    )


@router.get('/search', response_model=list[schemas.note.NoteSummary])
def search_notes(
    q: str = Query(..., min_length=1, description='Search keyword'),
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    service: NoteService = Depends(get_service),
) -> list[schemas.note.NoteSummary]:
    return service.search_notes(db=db, user_id=user_id, locale=lang, query=q, limit=limit)


@router.get('/{note_id}', response_model=schemas.note.Note)
def read_note(
    note_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: NoteService = Depends(get_service),
) -> schemas.note.Note:
    record = service.get_note(db=db, note_id=note_id, locale=lang)
    if record is None or record.user_id != user_id:
        raise HTTPException(status_code=404, detail='Note not found')
    return record


@router.put('/{note_id}', response_model=schemas.note.Note)
def update_note(
    note_id: str,
    note_in: schemas.note.NoteUpdate,
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: NoteService = Depends(get_service),
) -> schemas.note.Note:
    note_db = service.get_note_model(db=db, note_id=note_id)
    if note_db is None or note_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Note not found')
    return service.update_note(db=db, note_db=note_db, note_in=note_in, locale=lang)


@router.delete('/{note_id}', status_code=204)
def delete_note(
    note_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: NoteService = Depends(get_service),
) -> None:
    note_db = service.get_note_model(db=db, note_id=note_id)
    if note_db is None or note_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Note not found')
    service.delete_note(db=db, note_db=note_db)
