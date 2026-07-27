"""recipe direct allergens with notes

Revision ID: 7a3e9c1d5f02
Revises: 1bd2549f5256
Create Date: 2026-07-27 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7a3e9c1d5f02'
down_revision: Union[str, Sequence[str], None] = '1bd2549f5256'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('recipes', sa.Column('category', sa.String(), nullable=True))

    op.create_table(
        'food_item_allergens',
        sa.Column('food_item_id', sa.Integer(), nullable=False),
        sa.Column('allergen_id', sa.Integer(), nullable=False),
        sa.Column('certain', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('note', sa.String(), nullable=True),
        sa.ForeignKeyConstraint(['allergen_id'], ['allergens.id'], ),
        sa.ForeignKeyConstraint(['food_item_id'], ['food_items.id'], ),
        sa.PrimaryKeyConstraint('food_item_id', 'allergen_id'),
    )

    op.create_table(
        'recipe_allergens',
        sa.Column('recipe_id', sa.Integer(), nullable=False),
        sa.Column('allergen_id', sa.Integer(), nullable=False),
        sa.Column('certain', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('note', sa.String(), nullable=True),
        sa.ForeignKeyConstraint(['allergen_id'], ['allergens.id'], ),
        sa.ForeignKeyConstraint(['recipe_id'], ['recipes.id'], ),
        sa.PrimaryKeyConstraint('recipe_id', 'allergen_id'),
    )

    op.drop_table('recipe_items')
    op.drop_table('food_allergen_association')
    op.drop_table('food_allergen_may_contain_association')


def downgrade() -> None:
    """Downgrade schema."""
    op.create_table(
        'food_allergen_may_contain_association',
        sa.Column('food_item_id', sa.Integer(), nullable=False),
        sa.Column('allergen_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['allergen_id'], ['allergens.id'], ),
        sa.ForeignKeyConstraint(['food_item_id'], ['food_items.id'], ),
        sa.PrimaryKeyConstraint('food_item_id', 'allergen_id'),
    )
    op.create_table(
        'food_allergen_association',
        sa.Column('food_item_id', sa.Integer(), nullable=False),
        sa.Column('allergen_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['allergen_id'], ['allergens.id'], ),
        sa.ForeignKeyConstraint(['food_item_id'], ['food_items.id'], ),
        sa.PrimaryKeyConstraint('food_item_id', 'allergen_id'),
    )
    op.create_table(
        'recipe_items',
        sa.Column('recipe_id', sa.Integer(), nullable=False),
        sa.Column('food_item_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['food_item_id'], ['food_items.id'], ),
        sa.ForeignKeyConstraint(['recipe_id'], ['recipes.id'], ),
        sa.PrimaryKeyConstraint('recipe_id', 'food_item_id'),
    )

    op.drop_table('recipe_allergens')
    op.drop_table('food_item_allergens')

    op.drop_column('recipes', 'category')
