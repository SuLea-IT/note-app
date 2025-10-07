from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import jwt


class TokenService:
    """Generate and validate JWT access/refresh tokens."""

    def __init__(
        self,
        *,
        secret_key: str,
        algorithm: str,
        access_token_ttl: timedelta,
        refresh_token_ttl: timedelta,
    ) -> None:
        self._secret_key = secret_key
        self._algorithm = algorithm
        self._access_token_ttl = access_token_ttl
        self._refresh_token_ttl = refresh_token_ttl

    def create_access_token(self, subject: str) -> TokenPairElement:
        return self._create_token(subject=subject, token_type='access', ttl=self._access_token_ttl)

    def create_refresh_token(self, subject: str) -> TokenPairElement:
        return self._create_token(subject=subject, token_type='refresh', ttl=self._refresh_token_ttl)

    def build_session(self, subject: str) -> TokenPair:
        access = self.create_access_token(subject)
        refresh = self.create_refresh_token(subject)
        return TokenPair(access=access, refresh=refresh)

    def decode(self, token: str, *, expected_type: Literal['access', 'refresh']) -> dict[str, Any]:
        payload = jwt.decode(token, self._secret_key, algorithms=[self._algorithm])
        token_type = payload.get('type')
        if token_type != expected_type:
            msg = f'Invalid token type: expected {expected_type}, got {token_type}'
            raise jwt.InvalidTokenError(msg)
        return payload

    def refresh(self, refresh_token: str) -> TokenPair:
        payload = self.decode(refresh_token, expected_type='refresh')
        subject = str(payload.get('sub', ''))
        if not subject:
            raise jwt.InvalidTokenError('Refresh token missing subject')
        return self.build_session(subject)

    def _create_token(
        self,
        *,
        subject: str,
        token_type: Literal['access', 'refresh'],
        ttl: timedelta,
    ) -> TokenPairElement:
        now = datetime.now(timezone.utc)
        expire = now + ttl
        payload = {
            'sub': subject,
            'type': token_type,
            'iat': int(now.timestamp()),
            'exp': int(expire.timestamp()),
        }
        encoded = jwt.encode(payload, self._secret_key, algorithm=self._algorithm)
        return TokenPairElement(token=encoded, expires_at=expire)


class TokenPairElement:
    def __init__(self, *, token: str, expires_at: datetime) -> None:
        self.token = token
        self.expires_at = expires_at


class TokenPair:
    def __init__(self, *, access: TokenPairElement, refresh: TokenPairElement) -> None:
        self.access = access
        self.refresh = refresh

