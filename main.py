import os
import uuid
import asyncio
from typing import Optional
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, RedirectResponse
from pydantic import BaseModel
from sqlalchemy import select, Table, Column, Integer, String, ForeignKey
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from database import init_db, async_session, Base
import ocr_service

app = FastAPI(
    title="Food Allergen API",
    description="API for managing food items and their allergens",
    version="0.1.0"
)

food_allergen_association = Table(
    "food_allergen_association",
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
    name = Column(String, nullable=False, unique=True, index=True)
    description = Column(String, nullable=True)


class FoodItemORM(Base):
    __tablename__ = "food_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    category = Column(String, nullable=True)
    image_path = Column(String, nullable=True)

    allergens = None


class RecipeORM(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)

    items = None


# Late binding for relationship to avoid import order issues
from sqlalchemy.orm import relationship
FoodItemORM.allergens = relationship(
    "AllergenORM",
    secondary=food_allergen_association,
    back_populates="food_items",
    lazy="selectin"
)
AllergenORM.food_items = relationship(
    "FoodItemORM",
    secondary=food_allergen_association,
    back_populates="allergens",
    lazy="selectin"
)
RecipeORM.items = relationship(
    "FoodItemORM",
    secondary=recipe_items_association,
    lazy="selectin"
)


class AllergenBase(BaseModel):
    name: str
    description: Optional[str] = None


class AllergenCreate(AllergenBase):
    pass


class AllergenOut(AllergenBase):
    id: int

    class Config:
        from_attributes = True


class FoodItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    image_path: Optional[str] = None


class FoodItemCreate(FoodItemBase):
    allergen_ids: list[int] = []


class FoodItemOut(FoodItemBase):
    id: int
    allergens: list[AllergenOut]

    class Config:
        from_attributes = True


class FoodItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    image_path: Optional[str] = None
    allergen_ids: Optional[list[int]] = None


class RecipeCreate(BaseModel):
    name: str
    description: Optional[str] = None
    food_item_ids: list[int] = []


class RecipeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    food_item_ids: Optional[list[int]] = None


class RecipeAllergenOut(BaseModel):
    name: str
    count: int
    items: list[str]


class RecipeOut(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    items: list[FoodItemOut]
    allergens: list[RecipeAllergenOut]

    class Config:
        from_attributes = True


async def get_db() -> AsyncSession:
    async with async_session() as session:
        yield session


@app.on_event("startup")
async def on_startup():
    await init_db()


@app.get("/allergens", response_model=list[AllergenOut])
async def list_allergens(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(AllergenORM))
    return result.scalars().all()


@app.post("/allergens", response_model=AllergenOut)
async def create_allergen(allergen: AllergenCreate, db: AsyncSession = Depends(get_db)):
    db_allergen = AllergenORM(**allergen.model_dump())
    db.add(db_allergen)
    await db.commit()
    await db.refresh(db_allergen)
    return db_allergen


@app.get("/food-items", response_model=list[FoodItemOut])
async def list_food_items(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(FoodItemORM).options(selectinload(FoodItemORM.allergens)))
    return result.scalars().all()


@app.get("/food-items/suggest")
async def suggest_food_items(q: str = "", db: AsyncSession = Depends(get_db)):
    if not q:
        return []
    items_result = await db.execute(
        select(FoodItemORM)
        .where(FoodItemORM.name.ilike(f"%{q}%"))
        .limit(10)
    )
    items = items_result.scalars().all()
    recipes_result = await db.execute(
        select(RecipeORM)
        .where(RecipeORM.name.ilike(f"%{q}%"))
        .limit(5)
    )
    recipes = recipes_result.scalars().all()
    return {
        "items": [{"id": item.id, "name": item.name, "category": item.category} for item in items],
        "recipes": [{"id": r.id, "name": r.name, "type": "recipe"} for r in recipes],
    }


@app.get("/recipes", response_model=list[RecipeOut])
async def list_recipes(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(RecipeORM).options(selectinload(RecipeORM.items).selectinload(FoodItemORM.allergens))
    )
    recipes = result.scalars().all()
    return [_enrich_recipe(r) for r in recipes]


@app.post("/recipes", response_model=RecipeOut)
async def create_recipe(recipe: RecipeCreate, db: AsyncSession = Depends(get_db)):
    db_recipe = RecipeORM(name=recipe.name, description=recipe.description)
    if recipe.food_item_ids:
        items_result = await db.execute(
            select(FoodItemORM).where(FoodItemORM.id.in_(recipe.food_item_ids))
        )
        db_recipe.items = items_result.scalars().all()
    db.add(db_recipe)
    await db.commit()
    await db.refresh(db_recipe)
    # Eagerly load relationships after refresh
    await db.refresh(db_recipe, ["items"])
    for item in db_recipe.items:
        await db.refresh(item, ["allergens"])
    return _enrich_recipe(db_recipe)


@app.put("/recipes/{recipe_id}", response_model=RecipeOut)
async def update_recipe(recipe_id: int, data: RecipeUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(RecipeORM)
        .where(RecipeORM.id == recipe_id)
        .options(selectinload(RecipeORM.items).selectinload(FoodItemORM.allergens))
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if data.name is not None:
        recipe.name = data.name
    if data.description is not None:
        recipe.description = data.description
    if data.food_item_ids is not None:
        items_result = await db.execute(
            select(FoodItemORM).where(FoodItemORM.id.in_(data.food_item_ids))
        )
        recipe.items = items_result.scalars().all()
    await db.commit()
    await db.refresh(recipe, ["items"])
    for item in recipe.items:
        await db.refresh(item, ["allergens"])
    return _enrich_recipe(recipe)


@app.get("/recipes/{recipe_id}", response_model=RecipeOut)
async def read_recipe(recipe_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(RecipeORM)
        .where(RecipeORM.id == recipe_id)
        .options(selectinload(RecipeORM.items).selectinload(FoodItemORM.allergens))
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return _enrich_recipe(recipe)


@app.delete("/recipes/{recipe_id}")
async def delete_recipe(recipe_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(RecipeORM).where(RecipeORM.id == recipe_id))
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    await db.delete(recipe)
    await db.commit()
    return {"detail": "Recipe deleted"}


def _enrich_recipe(recipe: RecipeORM) -> dict:
    allergen_map: dict[str, dict] = {}
    for item in recipe.items:
        seen_in_item = set()
        for a in item.allergens:
            if a.name not in seen_in_item:
                seen_in_item.add(a.name)
                if a.name not in allergen_map:
                    allergen_map[a.name] = {"name": a.name, "count": 0, "items": set()}
                allergen_map[a.name]["count"] += 1
                allergen_map[a.name]["items"].add(item.name)
    return {
        "id": recipe.id,
        "name": recipe.name,
        "description": recipe.description,
        "items": [{
            "id": item.id,
            "name": item.name,
            "description": item.description,
            "category": item.category,
            "image_path": item.image_path,
            "allergens": [{"id": a.id, "name": a.name, "description": a.description} for a in item.allergens],
        } for item in recipe.items],
        "allergens": [
            {"name": v["name"], "count": v["count"], "items": sorted(v["items"])}
            for v in sorted(allergen_map.values(), key=lambda x: -x["count"])
        ],
    }


@app.get("/food-items/{item_id}", response_model=FoodItemOut)
async def read_food_item(item_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(FoodItemORM)
        .where(FoodItemORM.id == item_id)
        .options(selectinload(FoodItemORM.allergens))
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Food item not found")
    return item


@app.put("/food-items/{item_id}", response_model=FoodItemOut)
async def update_food_item(item_id: int, food: FoodItemUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(FoodItemORM)
        .where(FoodItemORM.id == item_id)
        .options(selectinload(FoodItemORM.allergens))
    )
    db_food = result.scalar_one_or_none()
    if not db_food:
        raise HTTPException(status_code=404, detail="Food item not found")

    if food.name is not None:
        db_food.name = food.name
    if food.description is not None:
        db_food.description = food.description
    if food.category is not None:
        db_food.category = food.category
    if food.image_path is not None:
        db_food.image_path = food.image_path
    if food.allergen_ids is not None:
        allergens_result = await db.execute(
            select(AllergenORM).where(AllergenORM.id.in_(food.allergen_ids))
        )
        db_food.allergens = allergens_result.scalars().all()

    await db.commit()
    await db.refresh(db_food)
    return db_food


@app.post("/food-items", response_model=FoodItemOut)
async def create_food_item(food: FoodItemCreate, db: AsyncSession = Depends(get_db)):
    db_food = FoodItemORM(name=food.name, description=food.description, category=food.category, image_path=food.image_path)
    if food.allergen_ids:
        allergens_result = await db.execute(
            select(AllergenORM).where(AllergenORM.id.in_(food.allergen_ids))
        )
        db_food.allergens = allergens_result.scalars().all()
    db.add(db_food)
    await db.commit()
    await db.refresh(db_food)
    return db_food


@app.delete("/food-items/{item_id}")
async def delete_food_item(item_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(FoodItemORM).where(FoodItemORM.id == item_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Food item not found")
    await db.delete(item)
    await db.commit()
    return {"detail": "Food item deleted"}


@app.post("/scan")
async def scan_image(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db)
):
    contents = await file.read()
    text_lines = await asyncio.to_thread(ocr_service.extract_text_from_image, contents)

    # Save the uploaded image
    ext = os.path.splitext(file.filename or "")[1] or ".jpg"
    filename = f"{uuid.uuid4()}{ext}"
    upload_dir = "static/uploads"
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)
    with open(filepath, "wb") as f:
        f.write(contents)

    # Load known allergens from the database
    result = await db.execute(select(AllergenORM))
    known_allergens = result.scalars().all()
    known_names = [a.name for a in known_allergens]

    # Match allergens in the extracted text
    found_names = ocr_service.find_allergens_in_text(text_lines, known_names)

    return {
        "image_path": f"/uploads/{filename}",
        "detected_allergens": [{"id": a.id, "name": a.name} for a in known_allergens if a.name in found_names],
        "all_allergens": [{"id": a.id, "name": a.name} for a in known_allergens]
    }


app.mount("/uploads", StaticFiles(directory="static/uploads"), name="uploads")
app.mount("/static", StaticFiles(directory="frontend/dist", html=True), name="static")


@app.get("/")
async def serve_index():
    return RedirectResponse(url="/static/")


@app.get("/health")
async def health_check():
    return {"status": "ok"}
