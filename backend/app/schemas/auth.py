from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from .user import User


class TokenPayload(BaseModel):
    access_token: str = Field(..., description='短期访问令牌')
    refresh_token: str = Field(..., description='刷新令牌，用于获取新的访问令牌')
    token_type: str = Field(default='bearer')
    expires_at: datetime = Field(..., description='访问令牌过期时间（UTC）')
    refresh_expires_at: datetime = Field(..., description='刷新令牌过期时间（UTC）')


class AuthSession(BaseModel):
    user: User
    tokens: TokenPayload


class TokenRefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=32)


class TokenRefreshResponse(BaseModel):
    tokens: TokenPayload

