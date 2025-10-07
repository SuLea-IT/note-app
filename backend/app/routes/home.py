from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..schemas.home import HomeFeed
from ..services.home_service import HomeService

router = APIRouter(prefix='/home', tags=['home'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> HomeService:
    return HomeService()


@router.get('/feed', response_model=HomeFeed)
async def fetch_home_feed(
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    db: Session = Depends(get_db),
    service: HomeService = Depends(get_service),
) -> HomeFeed:
    return service.get_feed(db=db, user_id=user_id, locale=lang)
