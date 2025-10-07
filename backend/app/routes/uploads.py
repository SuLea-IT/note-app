from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, HttpUrl

from ..config import BASE_DIR, get_settings

router = APIRouter(prefix='/uploads', tags=['uploads'])

_settings = get_settings()
_upload_root = (BASE_DIR.parent / 'data' / 'uploads').resolve()
_audio_dir = _upload_root / 'audio'


class AudioUploadResponse(BaseModel):
  file_url: HttpUrl
  size_bytes: int


def _ensure_directories() -> None:
  _audio_dir.mkdir(parents=True, exist_ok=True)


@router.post('/audio', response_model=AudioUploadResponse)
async def upload_audio(
  request: Request,
  file: UploadFile = File(...),
  user_id: str = Form(...),
) -> AudioUploadResponse:
  _ensure_directories()
  suffix = Path(file.filename or '').suffix or '.m4a'
  filename = f"{uuid.uuid4().hex}{suffix}"
  target_path = _audio_dir / filename

  size = 0
  with target_path.open('wb') as buffer:
    while True:
      chunk = await file.read(8192)
      if not chunk:
        break
      size += len(chunk)
      buffer.write(chunk)

  file_url = request.url_for('download_uploaded_audio', filename=filename)
  return AudioUploadResponse(file_url=file_url, size_bytes=size)


@router.get('/audio/{filename}', name='download_uploaded_audio')
async def download_audio(filename: str) -> FileResponse:
  _ensure_directories()
  path = _audio_dir / filename
  if not path.exists():
    raise HTTPException(status_code=404, detail='File not found')
  return FileResponse(path, media_type='audio/mpeg', filename=filename)
