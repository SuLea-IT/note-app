from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import schemas
from ..database import SessionLocal
from ..services.user_service import UserService
from .auth import get_token_service
from ..security import TokenService

router = APIRouter(prefix='/users', tags=['users'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> UserService:
    return UserService()


@router.get('', response_model=list[schemas.user.User])
def list_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
) -> list[schemas.user.User]:
    return service.list_users(db=db, skip=skip, limit=limit)


@router.get('/me', response_model=schemas.user.UserProfile)
def read_profile(
    user_id: str = Query(..., description='Current user identifier'),
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
) -> schemas.user.UserProfile:
    profile = service.get_profile(db=db, user_id=user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail='User not found')
    return profile


@router.post('', response_model=schemas.auth.AuthSession, status_code=201)
def create_user(
    payload: schemas.user.UserCreate,
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
    token_service: TokenService = Depends(get_token_service),
) -> schemas.auth.AuthSession:
    try:
        user_schema = service.create_user(db=db, payload=payload)
    except ValueError as err:
        if str(err) == 'email_already_registered':
            raise HTTPException(status_code=409, detail='Email already registered') from err
        raise
    token_pair = token_service.build_session(user_schema.id)
    return service.build_auth_session(user_schema, token_pair)


@router.get('/{user_id}', response_model=schemas.user.User)
def read_user(
    user_id: str,
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
) -> schemas.user.User:
    record = service.get_user(db=db, user_id=user_id)
    if record is None:
        raise HTTPException(status_code=404, detail='User not found')
    return record


@router.patch('/{user_id}', response_model=schemas.user.User)
def update_user(
    user_id: str,
    payload: schemas.user.UserUpdate,
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
) -> schemas.user.User:
    user_db = service.get_user_model(db=db, user_id=user_id)
    if user_db is None:
        raise HTTPException(status_code=404, detail='User not found')
    return service.update_user(db=db, user_db=user_db, payload=payload)


@router.delete('/{user_id}', status_code=204)
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
) -> None:
    user_db = service.get_user_model(db=db, user_id=user_id)
    if user_db is None:
        raise HTTPException(status_code=404, detail='User not found')
    service.delete_user(db=db, user_db=user_db)
