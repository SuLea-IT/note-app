"""Add tasks, reminders, and tags tables

Revision ID: b62b4d1f1c23
Revises: 9a3dd4e7c2b1
Create Date: 2025-10-06 04:45:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b62b4d1f1c23'
down_revision: Union[str, Sequence[str], None] = '9a3dd4e7c2b1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


task_priority_enum = sa.Enum('low', 'normal', 'high', 'urgent', name='taskpriority')
task_status_enum = sa.Enum('pending', 'in_progress', 'completed', 'cancelled', name='taskstatus')
task_association_enum = sa.Enum('note', 'diary', name='taskassociationtype')


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if 'tasks' not in tables:
        op.create_table(
            'tasks',
            sa.Column('id', sa.String(length=255), primary_key=True),
            sa.Column('user_id', sa.String(length=255), nullable=False),
            sa.Column('title', sa.String(length=255), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('due_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('all_day', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('priority', task_priority_enum, nullable=False, server_default=sa.text("'normal'")),
            sa.Column('status', task_status_enum, nullable=False, server_default=sa.text("'pending'")),
            sa.Column('order_index', sa.Integer(), nullable=True, server_default=sa.text('0')),
            sa.Column('related_entity_id', sa.String(length=255), nullable=True),
            sa.Column('related_entity_type', task_association_enum, nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        )
        op.create_index('ix_tasks_user_id', 'tasks', ['user_id'])
        op.create_index('ix_tasks_title', 'tasks', ['title'])
        op.create_index('ix_tasks_status', 'tasks', ['status'])
        op.create_index('ix_tasks_due_at', 'tasks', ['due_at'])

    if 'task_tags' not in tables:
        op.create_table(
            'task_tags',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column('user_id', sa.String(length=255), nullable=False),
            sa.Column('name', sa.String(length=64), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.UniqueConstraint('user_id', 'name', name='uq_task_tag_user_name'),
        )
        op.create_index('ix_task_tags_user_id', 'task_tags', ['user_id'])

    if 'task_tag_links' not in tables:
        op.create_table(
            'task_tag_links',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column('task_id', sa.String(length=255), nullable=False),
            sa.Column('tag_id', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.ForeignKeyConstraint(['tag_id'], ['task_tags.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['task_id'], ['tasks.id'], ondelete='CASCADE'),
            sa.UniqueConstraint('task_id', 'tag_id', name='uq_task_tag_link'),
        )
        op.create_index('ix_task_tag_links_task_id', 'task_tag_links', ['task_id'])
        op.create_index('ix_task_tag_links_tag_id', 'task_tag_links', ['tag_id'])

    if 'task_reminders' not in tables:
        op.create_table(
            'task_reminders',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column('task_id', sa.String(length=255), nullable=False),
            sa.Column('remind_at', sa.DateTime(timezone=True), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['task_id'], ['tasks.id'], ondelete='CASCADE'),
        )
        op.create_index('ix_task_reminders_task_id', 'task_reminders', ['task_id'])
        op.create_index('ix_task_reminders_remind_at', 'task_reminders', ['remind_at'])


def downgrade() -> None:
    op.drop_index('ix_task_reminders_remind_at', table_name='task_reminders')
    op.drop_index('ix_task_reminders_task_id', table_name='task_reminders')
    op.drop_table('task_reminders')

    op.drop_index('ix_task_tag_links_tag_id', table_name='task_tag_links')
    op.drop_index('ix_task_tag_links_task_id', table_name='task_tag_links')
    op.drop_table('task_tag_links')

    op.drop_index('ix_task_tags_user_id', table_name='task_tags')
    op.drop_table('task_tags')

    op.drop_index('ix_tasks_due_at', table_name='tasks')
    op.drop_index('ix_tasks_status', table_name='tasks')
    op.drop_index('ix_tasks_title', table_name='tasks')
    op.drop_index('ix_tasks_user_id', table_name='tasks')
    op.drop_table('tasks')

    bind = op.get_bind()
    if bind.dialect.name == 'postgresql':
        task_association_enum.drop(bind, checkfirst=True)
        task_status_enum.drop(bind, checkfirst=True)
        task_priority_enum.drop(bind, checkfirst=True)
