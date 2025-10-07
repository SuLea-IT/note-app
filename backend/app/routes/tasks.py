from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import schemas
from ..database import SessionLocal
from ..services.task_service import TaskService

router = APIRouter(prefix='/tasks', tags=['tasks'])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_service() -> TaskService:
    return TaskService()


@router.get('/', response_model=schemas.task.TaskCollection)
def list_tasks(
    user_id: str = Query(..., description='Target user identifier'),
    statuses: list[schemas.task.TaskStatus] | None = Query(None, alias='status'),
    priorities: list[schemas.task.TaskPriority] | None = Query(None, alias='priority'),
    tags: list[str] | None = Query(None, description='Filter by tag names'),
    due_from: datetime | None = Query(None, description='Inclusive lower bound for due date'),
    due_to: datetime | None = Query(None, description='Inclusive upper bound for due date'),
    search: str | None = Query(None, description='Search by title or description'),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    service: TaskService = Depends(get_service),
) -> schemas.task.TaskCollection:
    cleaned_search = search.strip() if search else None
    return service.list_tasks(
        db=db,
        user_id=user_id,
        statuses=statuses,
        priorities=priorities,
        tags=tags,
        due_from=due_from,
        due_to=due_to,
        search=cleaned_search,
        skip=skip,
        limit=limit,
    )


@router.get('/stats', response_model=schemas.task.TaskStatistics)
def task_statistics(
    user_id: str = Query(..., description='Target user identifier'),
    reference: datetime | None = Query(None, description='Reference timestamp for calculations'),
    db: Session = Depends(get_db),
    service: TaskService = Depends(get_service),
) -> schemas.task.TaskStatistics:
    return service.summary(db=db, user_id=user_id, reference=reference)


@router.post('/', response_model=schemas.task.Task, status_code=201)
def create_task(
    task_in: schemas.task.TaskCreate,
    db: Session = Depends(get_db),
    service: TaskService = Depends(get_service),
) -> schemas.task.Task:
    return service.create_task(db=db, task_in=task_in)


@router.get('/{task_id}', response_model=schemas.task.Task)
def read_task(
    task_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: TaskService = Depends(get_service),
) -> schemas.task.Task:
    record = service.get_task(db=db, task_id=task_id)
    if record is None or record.user_id != user_id:
        raise HTTPException(status_code=404, detail='Task not found')
    return record


@router.put('/{task_id}', response_model=schemas.task.Task)
def update_task(
    task_id: str,
    task_in: schemas.task.TaskUpdate,
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: TaskService = Depends(get_service),
) -> schemas.task.Task:
    task_db = service.get_task_model(db=db, task_id=task_id)
    if task_db is None or task_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Task not found')
    return service.update_task(db=db, task_db=task_db, task_in=task_in)


@router.delete('/{task_id}', status_code=204)
def delete_task(
    task_id: str,
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: TaskService = Depends(get_service),
) -> None:
    task_db = service.get_task_model(db=db, task_id=task_id)
    if task_db is None or task_db.user_id != user_id:
        raise HTTPException(status_code=404, detail='Task not found')
    service.delete_task(db=db, task_db=task_db)


@router.post('/bulk-complete', response_model=list[schemas.task.Task])
def bulk_complete_tasks(
    payload: schemas.task.TaskBulkCompletionRequest,
    user_id: str = Query(..., description='Target user identifier'),
    db: Session = Depends(get_db),
    service: TaskService = Depends(get_service),
) -> list[schemas.task.Task]:
    records = service.bulk_complete(
        db=db,
        user_id=user_id,
        task_ids=payload.task_ids,
        completed=payload.completed,
    )
    if not records:
        raise HTTPException(status_code=404, detail='No tasks updated')
    return records

