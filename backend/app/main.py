from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .routes import (
    auth,
    audio_notes,
    diaries,
    habits,
    home,
    notes,
    notifications,
    search,
    tasks,
    uploads,
    users,
)
from .scheduler import shutdown_scheduler, start_scheduler

settings = get_settings()

app = FastAPI(title=settings.project_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

app.include_router(auth.router, prefix=settings.api_prefix)
app.include_router(users.router, prefix=settings.api_prefix)
app.include_router(home.router, prefix=settings.api_prefix)
app.include_router(notes.router, prefix=settings.api_prefix)
app.include_router(habits.router, prefix=settings.api_prefix)
app.include_router(diaries.router, prefix=settings.api_prefix)
app.include_router(tasks.router, prefix=settings.api_prefix)
app.include_router(audio_notes.router, prefix=settings.api_prefix)
app.include_router(search.router, prefix=settings.api_prefix)
app.include_router(notifications.router, prefix=settings.api_prefix)
app.include_router(uploads.router, prefix=settings.api_prefix)


@app.get('/health', tags=['system'])
async def health_check() -> dict[str, str]:
    return {'status': 'ok'}


@app.on_event('startup')
async def startup_events() -> None:
    start_scheduler()


@app.on_event('shutdown')
async def shutdown_events() -> None:
    shutdown_scheduler()
