from sqlalchemy import Boolean, Column, Integer, String, ForeignKey, DateTime, Enum, UniqueConstraint, func
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


class AllergenORM(Base):
    __tablename__ = "allergens"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)

    __table_args__ = (UniqueConstraint("restaurant_id", "name", name="uq_allergen_restaurant_name"),)


class FoodItemAllergenORM(Base):
    __tablename__ = "food_item_allergens"

    food_item_id = Column(Integer, ForeignKey("food_items.id"), primary_key=True)
    allergen_id = Column(Integer, ForeignKey("allergens.id"), primary_key=True)
    certain = Column(Boolean, nullable=False, default=True)
    note = Column(String, nullable=True)

    allergen = relationship("AllergenORM", lazy="selectin")


class RecipeAllergenORM(Base):
    __tablename__ = "recipe_allergens"

    recipe_id = Column(Integer, ForeignKey("recipes.id"), primary_key=True)
    allergen_id = Column(Integer, ForeignKey("allergens.id"), primary_key=True)
    certain = Column(Boolean, nullable=False, default=True)
    note = Column(String, nullable=True)

    allergen = relationship("AllergenORM", lazy="selectin")


class FoodItemORM(Base):
    __tablename__ = "food_items"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    category = Column(String, nullable=True)
    image_path = Column(String, nullable=True)

    allergen_links = relationship(
        "FoodItemAllergenORM",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class RecipeORM(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    category = Column(String, nullable=True)

    allergen_links = relationship(
        "RecipeAllergenORM",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
