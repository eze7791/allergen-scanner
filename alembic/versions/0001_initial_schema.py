"""initial schema (allergens, food_items, recipes)

Revision ID: 0001_initial_schema
Revises:
Create Date: 2026-07-26 19:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '0001_initial_schema'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'allergens',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_allergens_id'), 'allergens', ['id'], unique=False)
    op.create_index(op.f('ix_allergens_name'), 'allergens', ['name'], unique=True)

    op.create_table(
        'food_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('category', sa.String(), nullable=True),
        sa.Column('image_path', sa.String(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_food_items_id'), 'food_items', ['id'], unique=False)
    op.create_index(op.f('ix_food_items_name'), 'food_items', ['name'], unique=False)

    op.create_table(
        'recipes',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_recipes_id'), 'recipes', ['id'], unique=False)
    op.create_index(op.f('ix_recipes_name'), 'recipes', ['name'], unique=False)

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


def downgrade() -> None:
    op.drop_table('recipe_items')
    op.drop_table('food_allergen_association')
    op.drop_index(op.f('ix_recipes_name'), table_name='recipes')
    op.drop_index(op.f('ix_recipes_id'), table_name='recipes')
    op.drop_table('recipes')
    op.drop_index(op.f('ix_food_items_name'), table_name='food_items')
    op.drop_index(op.f('ix_food_items_id'), table_name='food_items')
    op.drop_table('food_items')
    op.drop_index(op.f('ix_allergens_name'), table_name='allergens')
    op.drop_index(op.f('ix_allergens_id'), table_name='allergens')
    op.drop_table('allergens')
