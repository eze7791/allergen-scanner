"""admin username/password auth, decoupled from restaurant PIN

Revision ID: b4f1c9a02e77
Revises: 7a3e9c1d5f02
Create Date: 2026-07-27 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b4f1c9a02e77'
down_revision: Union[str, Sequence[str], None] = '7a3e9c1d5f02'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('users', sa.Column('username', sa.String(), nullable=True))
    op.add_column('users', sa.Column('password_hash', sa.String(), nullable=True))
    op.create_unique_constraint('uq_users_username', 'users', ['username'])
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)
    op.drop_column('restaurants', 'admin_pin_hash')


def downgrade() -> None:
    """Downgrade schema."""
    op.add_column('restaurants', sa.Column('admin_pin_hash', sa.String(), nullable=True))
    op.drop_index(op.f('ix_users_username'), table_name='users')
    op.drop_constraint('uq_users_username', 'users', type_='unique')
    op.drop_column('users', 'password_hash')
    op.drop_column('users', 'username')
