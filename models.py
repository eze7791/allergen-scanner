from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Enum, Table, UniqueConstraint, func
from sqlalchemy.orm import relationship
import enum

from database import Base


class UserRole(str, enum.Enum):
    admin = "admin"
    staff = "staff"


class RestaurantORM(Base):
    __tablename__ = "restaurants"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    join_code = Column(String, nullable=False, unique=True, index=True)
    admin_pin_hash = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    users = relationship("UserORM", back_populates="restaurant", lazy="selectin")


class UserORM(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False, index=True)
    role = Column(Enum(UserRole), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    restaurant = relationship("RestaurantORM", back_populates="users")


food_allergen_association = Table(
    "food_allergen_association",
    Base.metadata,
    Column("food_item_id", Integer, ForeignKey("food_items.id"), primary_key=True),
    Column("allergen_id", Integer, ForeignKey("allergens.id"), primary_key=True),
)

food_allergen_may_contain_association = Table(
    "food_allergen_may_contain_association",
    Base.metadata,
    Column("food_item_id", Integer, ForeignKey("food_items.id"), primary_key=True),
    Column("allergen_id", Integer, ForeignKey("allergens.id"), primary_key=True),
)

recipe_items_association = Table(
    "recipe_items",
    Base.metadata,
    Column("recipe_id", Integer, ForeignKey("recipes.id"), primary_key=True),
    Column("food_item_id", Integer, ForeignKey("food_items.id"), primary_key=True),
)


class AllergenORM(Base):
    __tablename__ = "allergens"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)

    __table_args__ = (UniqueConstraint("restaurant_id", "name", name="uq_allergen_restaurant_name"),)


class FoodItemORM(Base):
    __tablename__ = "food_items"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    category = Column(String, nullable=True)
    image_path = Column(String, nullable=True)

    allergens = relationship(
        "AllergenORM",
        secondary=food_allergen_association,
        lazy="selectin",
    )
    may_contain_allergens = relationship(
        "AllergenORM",
        secondary=food_allergen_may_contain_association,
        lazy="selectin",
    )


class RecipeORM(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)

    items = relationship(
        "FoodItemORM",
        secondary=recipe_items_association,
        lazy="selectin",
    )
