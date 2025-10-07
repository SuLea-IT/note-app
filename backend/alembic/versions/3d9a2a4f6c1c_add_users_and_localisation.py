"""Add users and localisation support

Revision ID: 3d9a2a4f6c1c
Revises: 06c84e43f468
Create Date: 2025-09-30 13:30:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = '3d9a2a4f6c1c'
down_revision: Union[str, Sequence[str], None] = '06c84e43f468'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


USER_SYSTEM_ID = 'system'
USER_SYSTEM_EMAIL = 'system@example.com'


note_category_enum = sa.Enum(
    'diary', 'checklist', 'idea', 'journal', 'reminder', name='notecategory'
)


users_table = sa.table(
    'users',
    sa.column('id', sa.String(length=255)),
    sa.column('email', sa.String(length=255)),
    sa.column('password_hash', sa.String(length=255)),
    sa.column('display_name', sa.String(length=255)),
    sa.column('preferred_locale', sa.String(length=32)),
)


def upgrade() -> None:
    """Upgrade schema for user ownership and localisation."""
    op.create_table(
        'users',
        sa.Column('id', sa.String(length=255), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('password_hash', sa.String(length=255), nullable=False),
        sa.Column('display_name', sa.String(length=255), nullable=True),
        sa.Column('preferred_locale', sa.String(length=32), nullable=False, server_default='en-US'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    op.bulk_insert(
        users_table,
        [
            {
                'id': USER_SYSTEM_ID,
                'email': USER_SYSTEM_EMAIL,
                'password_hash': 'salt$hash',
                'display_name': 'System',
                'preferred_locale': 'en-US',
            }
        ],
    )

    op.add_column(
        'habits',
        sa.Column('user_id', sa.String(length=255), nullable=False, server_default=USER_SYSTEM_ID),
    )
    op.add_column(
        'habits',
        sa.Column('default_locale', sa.String(length=32), nullable=False, server_default='en-US'),
    )
    op.create_index(op.f('ix_habits_user_id'), 'habits', ['user_id'], unique=False)
    op.create_foreign_key(
        'fk_habits_user_id_users',
        'habits',
        'users',
        ['user_id'],
        ['id'],
        ondelete='CASCADE',
    )

    op.add_column(
        'diaries',
        sa.Column('user_id', sa.String(length=255), nullable=False, server_default=USER_SYSTEM_ID),
    )
    op.add_column(
        'diaries',
        sa.Column('content', sa.Text(), nullable=True),
    )
    op.add_column(
        'diaries',
        sa.Column('default_locale', sa.String(length=32), nullable=False, server_default='en-US'),
    )
    op.create_index(op.f('ix_diaries_user_id'), 'diaries', ['user_id'], unique=False)
    op.create_foreign_key(
        'fk_diaries_user_id_users',
        'diaries',
        'users',
        ['user_id'],
        ['id'],
        ondelete='CASCADE',
    )

    op.execute(
        sa.text('UPDATE habits SET user_id = :system_id').bindparams(system_id=USER_SYSTEM_ID)
    )
    op.execute(
        sa.text('UPDATE diaries SET user_id = :system_id').bindparams(system_id=USER_SYSTEM_ID)
    )

    op.alter_column('habits', 'user_id', server_default=None)
    op.alter_column('diaries', 'user_id', server_default=None)

    bind = op.get_bind()
    note_category_enum.create(bind, checkfirst=True)

    op.create_table(
        'notes',
        sa.Column('id', sa.String(length=255), nullable=False),
        sa.Column('user_id', sa.String(length=255), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=True),
        sa.Column('preview', sa.String(length=1024), nullable=True),
        sa.Column('content', sa.Text(), nullable=True),
        sa.Column('date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('category', note_category_enum, nullable=True),
        sa.Column('has_attachment', sa.Boolean(), nullable=False, server_default=sa.text('0')),
        sa.Column('progress_percent', sa.Float(), nullable=False, server_default='0'),
        sa.Column('default_locale', sa.String(length=32), nullable=False, server_default='en-US'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE', name='fk_notes_user_id_users'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_notes_title'), 'notes', ['title'], unique=False)
    op.create_index(op.f('ix_notes_user_id'), 'notes', ['user_id'], unique=False)

    op.create_table(
        'diary_translations',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('diary_id', sa.String(length=255), nullable=False),
        sa.Column('locale', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('preview', sa.String(length=1024), nullable=True),
        sa.Column('content', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ['diary_id'], ['diaries.id'], ondelete='CASCADE', name='fk_diary_translations_diary_id'
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('diary_id', 'locale', name='uq_diary_translation_locale'),
    )
    op.create_index(op.f('ix_diary_translations_diary_id'), 'diary_translations', ['diary_id'], unique=False)

    op.create_table(
        'habit_translations',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('habit_id', sa.String(length=255), nullable=False),
        sa.Column('locale', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.String(length=1024), nullable=True),
        sa.Column('time_label', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ['habit_id'], ['habits.id'], ondelete='CASCADE', name='fk_habit_translations_habit_id'
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('habit_id', 'locale', name='uq_habit_translation_locale'),
    )
    op.create_index(op.f('ix_habit_translations_habit_id'), 'habit_translations', ['habit_id'], unique=False)

    op.create_table(
        'note_translations',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('note_id', sa.String(length=255), nullable=False),
        sa.Column('locale', sa.String(length=32), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('preview', sa.String(length=1024), nullable=True),
        sa.Column('content', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ['note_id'], ['notes.id'], ondelete='CASCADE', name='fk_note_translations_note_id'
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('note_id', 'locale', name='uq_note_translation_locale'),
    )
    op.create_index(op.f('ix_note_translations_note_id'), 'note_translations', ['note_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema changes."""
    op.drop_index(op.f('ix_note_translations_note_id'), table_name='note_translations')
    op.drop_table('note_translations')

    op.drop_index(op.f('ix_habit_translations_habit_id'), table_name='habit_translations')
    op.drop_table('habit_translations')

    op.drop_index(op.f('ix_diary_translations_diary_id'), table_name='diary_translations')
    op.drop_table('diary_translations')

    op.drop_index(op.f('ix_notes_user_id'), table_name='notes')
    op.drop_index(op.f('ix_notes_title'), table_name='notes')
    op.drop_table('notes')

    note_category_enum.drop(op.get_bind(), checkfirst=True)

    op.drop_constraint('fk_diaries_user_id_users', 'diaries', type_='foreignkey')
    op.drop_index(op.f('ix_diaries_user_id'), table_name='diaries')
    op.drop_column('diaries', 'default_locale')
    op.drop_column('diaries', 'content')
    op.drop_column('diaries', 'user_id')

    op.drop_constraint('fk_habits_user_id_users', 'habits', type_='foreignkey')
    op.drop_index(op.f('ix_habits_user_id'), table_name='habits')
    op.drop_column('habits', 'default_locale')
    op.drop_column('habits', 'user_id')

    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')
