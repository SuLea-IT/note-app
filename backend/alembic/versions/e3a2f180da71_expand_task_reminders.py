"""Expand task reminders with scheduling metadata

Revision ID: e3a2f180da71
Revises: d9f4c3b2a6e1
Create Date: 2025-10-07 08:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e3a2f180da71'
down_revision: Union[str, Sequence[str], None] = 'd9f4c3b2a6e1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


notification_channel_enum = sa.Enum('push', 'local', 'email', name='notificationchannel')
task_reminder_repeat_enum = sa.Enum(
    'none', 'daily', 'weekly', 'monthly', name='taskreminderrepeat'
)


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == 'postgresql':
        notification_channel_enum.create(bind, checkfirst=True)
        task_reminder_repeat_enum.create(bind, checkfirst=True)

    op.add_column(
        'task_reminders',
        sa.Column(
            'timezone',
            sa.String(length=64),
            nullable=False,
            server_default=sa.text("'UTC'"),
        ),
    )
    op.add_column(
        'task_reminders',
        sa.Column(
            'channel',
            notification_channel_enum,
            nullable=False,
            server_default=sa.text("'push'"),
        ),
    )
    op.add_column(
        'task_reminders',
        sa.Column(
            'repeat_rule',
            task_reminder_repeat_enum,
            nullable=False,
            server_default=sa.text("'none'"),
        ),
    )
    op.add_column(
        'task_reminders',
        sa.Column(
            'repeat_every',
            sa.Integer(),
            nullable=False,
            server_default=sa.text('1'),
        ),
    )
    op.add_column(
        'task_reminders',
        sa.Column(
            'active',
            sa.Boolean(),
            nullable=False,
            server_default=sa.text('1'),
        ),
    )
    op.add_column(
        'task_reminders',
        sa.Column('last_triggered_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'task_reminders',
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('task_reminders', 'expires_at')
    op.drop_column('task_reminders', 'last_triggered_at')
    op.drop_column('task_reminders', 'active')
    op.drop_column('task_reminders', 'repeat_every')
    op.drop_column('task_reminders', 'repeat_rule')
    op.drop_column('task_reminders', 'channel')
    op.drop_column('task_reminders', 'timezone')

    bind = op.get_bind()
    if bind.dialect.name == 'postgresql':
        task_reminder_repeat_enum.drop(bind, checkfirst=True)
        notification_channel_enum.drop(bind, checkfirst=True)
