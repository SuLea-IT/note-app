from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..schemas import auth as auth_schema
from ..schemas.user import UserCredentials
from ..services.user_service import UserService
from ..config import get_settings
from ..security import TokenService

router = APIRouter(prefix='/auth', tags=['auth'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> UserService:
    return UserService()


def get_token_service() -> TokenService:
    settings = get_settings()
    return TokenService(
        secret_key=settings.auth_secret_key,
        algorithm=settings.auth_algorithm,
        access_token_ttl=_minutes(settings.auth_access_token_expire_minutes),
        refresh_token_ttl=_days(settings.auth_refresh_token_expire_days),
    )


@router.post('/login', response_model=auth_schema.AuthSession)
async def login(
    credentials: UserCredentials,
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
    token_service: TokenService = Depends(get_token_service),
) -> auth_schema.AuthSession:
    user = service.verify_credentials(
        db=db, email=credentials.email, password=credentials.password
    )
    if user is None:
        raise HTTPException(status_code=401, detail='Invalid email or password')
    token_pair = token_service.build_session(user.id)
    return service.build_auth_session(user, token_pair)


@router.post('/refresh', response_model=auth_schema.TokenRefreshResponse)
async def refresh(
    payload: auth_schema.TokenRefreshRequest,
    db: Session = Depends(get_db),
    service: UserService = Depends(get_service),
    token_service: TokenService = Depends(get_token_service),
) -> auth_schema.TokenRefreshResponse:
    decoded = token_service.decode(payload.refresh_token, expected_type='refresh')
    subject = str(decoded.get('sub', '')).strip()
    if not subject:
        raise HTTPException(status_code=400, detail='Malformed refresh token')

    user_db = service.get_user_model(db=db, user_id=subject)
    if user_db is None:
        raise HTTPException(status_code=404, detail='User not found')

    user_schema = service.touch_last_active(db=db, user_db=user_db)
    token_pair = token_service.build_session(subject)
    auth_session = service.build_auth_session(user_schema, token_pair)
    return auth_schema.TokenRefreshResponse(tokens=auth_session.tokens)


def _minutes(value: int) -> timedelta:
    return timedelta(minutes=value)


def _days(value: int) -> timedelta:
    return timedelta(days=value)
