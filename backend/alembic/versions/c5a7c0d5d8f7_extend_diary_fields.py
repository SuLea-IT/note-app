"""Extend diary fields with sharing metadata

Revision ID: c5a7c0d5d8f7
Revises: 3d9a2a4f6c1c
Create Date: 2025-09-30 16:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c5a7c0d5d8f7'
down_revision: Union[str, Sequence[str], None] = '3d9a2a4f6c1c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema by adding diary presentation fields."""
    op.add_column('diaries', sa.Column('weather', sa.String(length=255), nullable=True))
    op.add_column('diaries', sa.Column('tags', sa.Text(), nullable=True))
    op.add_column(
        'diaries',
        sa.Column('can_share', sa.Boolean(), nullable=False, server_default=sa.text('0')),
    )
    op.add_column('diaries', sa.Column('template_id', sa.String(length=255), nullable=True))

    op.execute(sa.text("UPDATE diaries SET category = 'journal' WHERE category IS NULL"))
    op.execute(sa.text("UPDATE diaries SET date = CURRENT_TIMESTAMP WHERE date IS NULL"))
    op.execute(sa.text("UPDATE diaries SET can_share = 0 WHERE can_share IS NULL"))

    op.alter_column('diaries', 'can_share', server_default=None)


def downgrade() -> None:
    """Remove diary presentation fields."""
    op.drop_column('diaries', 'template_id')
    op.drop_column('diaries', 'can_share')
    op.drop_column('diaries', 'tags')
    op.drop_column('diaries', 'weather')
