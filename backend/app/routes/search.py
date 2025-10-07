from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..schemas import search as search_schema
from ..services.search_service import SearchService

router = APIRouter(prefix='/search', tags=['search'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> SearchService:
    return SearchService()


@router.get('/', response_model=search_schema.SearchResponse)
def global_search(
    q: str = Query(..., min_length=1, description='Search keyword'),
    user_id: str = Query(..., description='Target user identifier'),
    lang: str = Query('en-US', description='Preferred locale'),
    types: list[search_schema.SearchResultType] | None = Query(
        None, description='Filter by resource types'
    ),
    start_date: datetime | None = Query(
        None, description='Start date filter (applies to dated resources)'
    ),
    end_date: datetime | None = Query(
        None, description='End date filter (applies to dated resources)'
    ),
    limit: int = Query(50, ge=1, le=200, description='Maximum number of results'),
    db: Session = Depends(get_db),
    service: SearchService = Depends(get_service),
) -> search_schema.SearchResponse:
    return service.search(
        db=db,
        user_id=user_id,
        query=q,
        locale=lang,
        types=types,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )

