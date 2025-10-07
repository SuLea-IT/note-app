"""Add diary shares table and mood field

Revision ID: f17b2c0b4a5a
Revises: c5a7c0d5d8f7
Create Date: 2025-10-06 00:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f17b2c0b4a5a'
down_revision: Union[str, Sequence[str], None] = 'c5a7c0d5d8f7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Introduce diary sharing metadata."""
    op.add_column('diaries', sa.Column('mood', sa.String(length=64), nullable=True))

    op.create_table(
        'diary_shares',
        sa.Column('id', sa.String(length=255), primary_key=True),
        sa.Column('diary_id', sa.String(length=255), nullable=False, unique=True),
        sa.Column('share_code', sa.String(length=64), nullable=False, unique=True),
        sa.Column('share_url', sa.String(length=1024), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ['diary_id'],
            ['diaries.id'],
            ondelete='CASCADE',
        ),
    )


def downgrade() -> None:
    """Remove diary sharing metadata."""
    op.drop_table('diary_shares')
    op.drop_column('diaries', 'mood')
