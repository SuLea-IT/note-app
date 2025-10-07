from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent
ROOT_DIR = BASE_DIR.parent


from pydantic import computed_field


class Settings(BaseSettings):
    api_prefix: str = Field(default='/api')
    project_name: str = Field(default='note-app-backend')
    share_base_url: str = Field(
        default='https://note-app.example.com/share',
        alias='SHARE_BASE_URL',
    )

    firebase_credentials_file: str | None = Field(
        default=None,
        alias='FIREBASE_CREDENTIALS_FILE',
    )
    notification_default_timezone: str = Field(
        default='UTC',
        alias='NOTIFICATION_DEFAULT_TIMEZONE',
    )
    notification_poll_interval_seconds: int = Field(
        default=60,
        alias='NOTIFICATION_POLL_INTERVAL_SECONDS',
        ge=15,
        le=600,
    )
    notification_batch_window_minutes: int = Field(
        default=5,
        alias='NOTIFICATION_BATCH_WINDOW_MINUTES',
        ge=1,
        le=60,
    )

    auth_secret_key: str = Field(default='change-me', alias='AUTH_SECRET_KEY')
    auth_algorithm: str = Field(default='HS256', alias='AUTH_ALGORITHM')
    auth_access_token_expire_minutes: int = Field(
        default=60,
        alias='AUTH_ACCESS_TOKEN_EXPIRE_MINUTES',
    )
    auth_refresh_token_expire_days: int = Field(
        default=14,
        alias='AUTH_REFRESH_TOKEN_EXPIRE_DAYS',
    )

    db_host: str = Field(default='127.0.0.1', alias='DB_HOST')
    db_port: int = Field(default=3306, alias='DB_PORT')
    db_name: str = Field(default='note_app', alias='DB_NAME')
    db_user: str = Field(default='root', alias='DB_USER')
    db_password: str = Field(default='', alias='DB_PASSWORD')

    model_config = SettingsConfigDict(
        env_file=ROOT_DIR / '.env',
        env_file_encoding='utf-8',
    )

    @computed_field
    @property
    def database_url(self) -> str:
        return (
            'mysql+pymysql://'
            f'{self.db_user}:{self.db_password}'
            f'@{self.db_host}:{self.db_port}/{self.db_name}'
        )


@lru_cache()
def get_settings() -> Settings:
    return Settings()
