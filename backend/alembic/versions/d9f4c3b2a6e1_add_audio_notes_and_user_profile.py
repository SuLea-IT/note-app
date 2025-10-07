"""Add audio notes and extend user profile

Revision ID: d9f4c3b2a6e1
Revises: b62b4d1f1c23
Create Date: 2025-10-06 06:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd9f4c3b2a6e1'
down_revision: Union[str, Sequence[str], None] = 'b62b4d1f1c23'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


audio_status_enum = sa.Enum('pending', 'processing', 'completed', 'failed', name='audionotestatus')


def upgrade() -> None:
    op.add_column('users', sa.Column('avatar_url', sa.String(length=512), nullable=True))
    op.add_column('users', sa.Column('theme_preference', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('last_active_at', sa.DateTime(timezone=True), nullable=True))

    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if 'audio_notes' not in tables:
        op.create_table(
            'audio_notes',
            sa.Column('id', sa.String(length=255), primary_key=True),
            sa.Column('user_id', sa.String(length=255), nullable=False),
            sa.Column('title', sa.String(length=255), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('file_url', sa.String(length=1024), nullable=False),
            sa.Column('mime_type', sa.String(length=128), nullable=False, server_default='audio/mpeg'),
            sa.Column('size_bytes', sa.BigInteger(), nullable=True),
            sa.Column('duration_seconds', sa.Float(), nullable=True),
            sa.Column('transcription_status', audio_status_enum, nullable=False, server_default=sa.text("'pending'")),
            sa.Column('transcription_text', sa.Text(), nullable=True),
            sa.Column('transcription_language', sa.String(length=32), nullable=True),
            sa.Column('transcription_updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('transcription_error', sa.String(length=512), nullable=True),
            sa.Column('recorded_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        )
        op.create_index('ix_audio_notes_user_id', 'audio_notes', ['user_id'])
        op.create_index('ix_audio_notes_transcription_status', 'audio_notes', ['transcription_status'])


def downgrade() -> None:
    op.drop_index('ix_audio_notes_transcription_status', table_name='audio_notes')
    op.drop_index('ix_audio_notes_user_id', table_name='audio_notes')
    op.drop_table('audio_notes')

    op.drop_column('users', 'last_active_at')
    op.drop_column('users', 'theme_preference')
    op.drop_column('users', 'avatar_url')

    bind = op.get_bind()
    if bind.dialect.name == 'postgresql':
        audio_status_enum.drop(bind, checkfirst=True)
