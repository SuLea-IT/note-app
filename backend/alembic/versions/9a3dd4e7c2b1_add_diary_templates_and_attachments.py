"""Add diary templates and attachments tables

Revision ID: 9a3dd4e7c2b1
Revises: 8f3e5c4a9b1c
Create Date: 2025-10-06 03:25:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9a3dd4e7c2b1'
down_revision: Union[str, Sequence[str], None] = '8f3e5c4a9b1c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if 'diary_templates' not in tables:
        op.create_table(
            'diary_templates',
            sa.Column('id', sa.String(length=255), primary_key=True),
            sa.Column('icon', sa.String(length=255), nullable=True),
            sa.Column(
                'accent_color',
                sa.BigInteger(),
                nullable=False,
                server_default=sa.text(str(0xFFFF8B3D)),
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
            'ix_diary_templates_id',
            'diary_templates',
            ['id'],
            unique=False,
        )

    if 'diary_template_translations' not in tables:
        op.create_table(
            'diary_template_translations',
            sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
            sa.Column('template_id', sa.String(length=255), nullable=False),
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
                ['template_id'],
                ['diary_templates.id'],
                name='fk_diary_template_translations_template_id',
                ondelete='CASCADE',
            ),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint(
                'template_id', 'locale', name='uq_diary_template_translation_locale'
            ),
        )
        op.create_index(
            'ix_diary_template_translations_template_id',
            'diary_template_translations',
            ['template_id'],
            unique=False,
        )

    if 'diary_attachments' not in tables:
        op.create_table(
            'diary_attachments',
            sa.Column('id', sa.String(length=255), primary_key=True),
            sa.Column('diary_id', sa.String(length=255), nullable=False),
            sa.Column('file_name', sa.String(length=255), nullable=False),
            sa.Column('file_url', sa.String(length=1024), nullable=False),
            sa.Column('mime_type', sa.String(length=255), nullable=True),
            sa.Column('size_bytes', sa.Integer(), nullable=True),
            sa.Column(
                'created_at',
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
            sa.ForeignKeyConstraint(
                ['diary_id'],
                ['diaries.id'],
                name='fk_diary_attachments_diary_id',
                ondelete='CASCADE',
            ),
        )
        op.create_index(
            'ix_diary_attachments_diary_id',
            'diary_attachments',
            ['diary_id'],
            unique=False,
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if 'diary_attachments' in tables:
        op.drop_index('ix_diary_attachments_diary_id', table_name='diary_attachments')
        op.drop_table('diary_attachments')

    if 'diary_template_translations' in tables:
        op.drop_index(
            'ix_diary_template_translations_template_id',
            table_name='diary_template_translations',
        )
        op.drop_table('diary_template_translations')

    if 'diary_templates' in tables:
        existing_indexes = {
            idx['name'] for idx in inspector.get_indexes('diary_templates')
        }
        if 'ix_diary_templates_id' in existing_indexes:
            op.drop_index('ix_diary_templates_id', table_name='diary_templates')
        op.drop_table('diary_templates')

