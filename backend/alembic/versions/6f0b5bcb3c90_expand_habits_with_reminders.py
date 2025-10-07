"""Expand habits with reminders and history

Revision ID: 6f0b5bcb3c90
Revises: f17b2c0b4a5a
Create Date: 2025-10-06 02:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '6f0b5bcb3c90'
down_revision: Union[str, Sequence[str], None] = 'f17b2c0b4a5a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_columns = {column['name'] for column in inspector.get_columns('habits')}

    if 'reminder_time' not in existing_columns:
        op.add_column('habits', sa.Column('reminder_time', sa.Time(), nullable=True))
    if 'repeat_rule' not in existing_columns:
        op.add_column('habits', sa.Column('repeat_rule', sa.String(length=64), nullable=True))
    if 'accent_color' not in existing_columns:
        op.add_column(
            'habits',
            sa.Column(
                'accent_color',
                sa.BigInteger(),
                nullable=True,
                server_default=sa.text(str(0xFF7C4DFF)),
            ),
        )

    op.create_table(
        'habit_entries',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('habit_id', sa.String(length=255), nullable=False),
        sa.Column('entry_date', sa.Date(), nullable=False),
        sa.Column('status', sa.Enum('upcoming', 'in_progress', 'completed', name='habitstatus'), nullable=False, server_default='completed'),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('duration_minutes', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['habit_id'], ['habits.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('habit_id', 'entry_date', name='uq_habit_entry_unique_day'),
    )
    op.create_index(op.f('ix_habit_entries_habit_id'), 'habit_entries', ['habit_id'], unique=False)

    if 'accent_color' not in existing_columns:
        op.alter_column('habits', 'accent_color', server_default=None)


def downgrade() -> None:
    op.drop_index(op.f('ix_habit_entries_habit_id'), table_name='habit_entries')
    op.drop_table('habit_entries')
    op.drop_column('habits', 'accent_color')
    op.drop_column('habits', 'repeat_rule')
    op.drop_column('habits', 'reminder_time')
