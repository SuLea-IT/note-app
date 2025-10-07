from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import schemas
from ..database import SessionLocal
from ..services.audio_note_service import AudioNoteService

router = APIRouter(prefix='/audio-notes', tags=['audio-notes'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> AudioNoteService:
    return AudioNoteService()


@router.get('/', response_model=schemas.audio_note.AudioNoteCollection)
def list_audio_notes(
    user_id: str = Query(..., description='Owner user identifier'),
    statuses: list[schemas.audio_note.AudioNoteStatus] | None = Query(None, alias='status'),
    search: str | None = Query(None, description='Filter by title or description'),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    service: AudioNoteService = Depends(get_service),
) -> schemas.audio_note.AudioNoteCollection:
    cleaned_search = search.strip() if search else None
    return service.list_audio_notes(
        db=db,
        user_id=user_id,
        statuses=statuses,
        search=cleaned_search,
        skip=skip,
        limit=limit,
    )


@router.get('/{audio_note_id}', response_model=schemas.audio_note.AudioNote)
def read_audio_note(
    audio_note_id: str,
    user_id: str = Query(..., description='Owner user identifier'),
    db: Session = Depends(get_db),
    service: AudioNoteService = Depends(get_service),
) -> schemas.audio_note.AudioNote:
    record = service.get_audio_note(db=db, note_id=audio_note_id)
    if record is None or record.user_id != user_id:
        raise HTTPException(status_code=404, detail='Audio note not found')
    return record


@router.post('/', response_model=schemas.audio_note.AudioNote, status_code=201)
def create_audio_note(
    payload: schemas.audio_note.AudioNoteCreate,
    db: Session = Depends(get_db),
    service: AudioNoteService = Depends(get_service),
) -> schemas.audio_note.AudioNote:
    return service.create_audio_note(db=db, payload=payload)


@router.put('/{audio_note_id}', response_model=schemas.audio_note.AudioNote)
def update_audio_note(
    audio_note_id: str,
    payload: schemas.audio_note.AudioNoteUpdate,
    user_id: str = Query(..., description='Owner user identifier'),
    db: Session = Depends(get_db),
    service: AudioNoteService = Depends(get_service),
) -> schemas.audio_note.AudioNote:
    note_db = service.get_audio_note_model(db=db, note_id=audio_note_id)
    if note_db is None or note_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Audio note not found')
    return service.update_audio_note(db=db, note_db=note_db, payload=payload)


@router.patch('/{audio_note_id}/transcription', response_model=schemas.audio_note.AudioNote)
def update_transcription(
    audio_note_id: str,
    payload: schemas.audio_note.AudioNoteTranscriptionUpdate,
    user_id: str = Query(..., description='Owner user identifier'),
    db: Session = Depends(get_db),
    service: AudioNoteService = Depends(get_service),
) -> schemas.audio_note.AudioNote:
    note_db = service.get_audio_note_model(db=db, note_id=audio_note_id)
    if note_db is None or note_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Audio note not found')
    return service.update_transcription(db=db, note_db=note_db, payload=payload)


@router.delete('/{audio_note_id}', status_code=204)
def delete_audio_note(
    audio_note_id: str,
    user_id: str = Query(..., description='Owner user identifier'),
    db: Session = Depends(get_db),
    service: AudioNoteService = Depends(get_service),
) -> None:
    note_db = service.get_audio_note_model(db=db, note_id=audio_note_id)
    if note_db is None or note_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Audio note not found')
    service.delete_audio_note(db=db, note_db=note_db)

