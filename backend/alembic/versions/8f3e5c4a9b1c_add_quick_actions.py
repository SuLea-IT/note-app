"""Add quick action tables

Revision ID: 8f3e5c4a9b1c
Revises: 6f0b5bcb3c90
Create Date: 2025-10-06 03:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8f3e5c4a9b1c'
down_revision: Union[str, Sequence[str], None] = '6f0b5bcb3c90'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if 'quick_actions' not in tables:
        op.create_table(
            'quick_actions',
            sa.Column('id', sa.String(length=255), primary_key=True),
            sa.Column('icon', sa.String(length=255), nullable=True),
            sa.Column('order_index', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column(
                'background_color',
                sa.BigInteger(),
                nullable=False,
                server_default=sa.text(str(0xFFFFFFFF)),
            ),
            sa.Column(
                'foreground_color',
                sa.BigInteger(),
                nullable=False,
                server_default=sa.text(str(0xFF000000)),
            ),
            sa.Column('default_title', sa.String(length=255), nullable=False, server_default=''),
            sa.Column('default_subtitle', sa.String(length=255), nullable=False, server_default=''),
            sa.Column('default_locale', sa.String(length=32), nullable=False, server_default='en'),
            sa.Column(
                'created_at',
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
            sa.Column(
                'updated_at',
                sa.DateTime(timezone=True),
                nullable=True,
                server_default=sa.func.now(),
            ),
        )
        op.create_index(
            'ix_quick_actions_order_index',
            'quick_actions',
            ['order_index', 'id'],
            unique=False,
        )

    if 'quick_action_translations' not in tables:
        op.create_table(
            'quick_action_translations',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column('action_id', sa.String(length=255), nullable=False),
            sa.Column('locale', sa.String(length=32), nullable=False),
            sa.Column('title', sa.String(length=255), nullable=False),
            sa.Column('subtitle', sa.String(length=255), nullable=False, server_default=''),
            sa.Column(
                'created_at',
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
            sa.Column(
                'updated_at',
                sa.DateTime(timezone=True),
                nullable=True,
                server_default=sa.func.now(),
            ),
            sa.ForeignKeyConstraint(
                ['action_id'],
                ['quick_actions.id'],
                name='fk_quick_action_translations_action_id',
                ondelete='CASCADE',
            ),
            sa.UniqueConstraint(
                'action_id',
                'locale',
                name='uq_quick_action_translation_locale',
            ),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if 'quick_action_translations' in tables:
        op.drop_table('quick_action_translations')

    if 'quick_actions' in tables:
        existing_indexes = {idx['name'] for idx in inspector.get_indexes('quick_actions')}
        if 'ix_quick_actions_order_index' in existing_indexes:
            op.drop_index('ix_quick_actions_order_index', table_name='quick_actions')
        op.drop_table('quick_actions')
