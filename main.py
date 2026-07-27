import os
import uuid
import asyncio
from typing import Optional
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from database import init_db
from models import (
    AllergenORM,
    FoodItemAllergenORM,
    FoodItemORM,
    RecipeAllergenORM,
    RecipeORM,
    RestaurantORM,
    UserORM,
    UserRole,
)
from allergen_matching import find_allergens_in_text
from auth import (
    get_db,
    get_current_user,
    require_admin,
    hash_pin,
    verify_pin,
    generate_join_code,
    create_access_token,
)
try:
    import ocr_service
except ImportError:
    # easyocr/torch are heavy and only needed for the browser-based image
    # upload scan; deployments that skip them still support /scan/text
    # (allergen matching against text already extracted on-device, e.g. iOS).
    ocr_service = None

app = FastAPI(
    title="Food Allergen API",
    description="API for managing food items and their allergens",
    version="0.2.0"
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


class LinkedAllergenOut(AllergenBase):
    id: int
    note: Optional[str] = None

    class Config:
        from_attributes = True


class FoodItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    image_path: Optional[str] = None


class FoodItemCreate(FoodItemBase):
    allergen_ids: list[int] = []
    may_contain_allergen_ids: list[int] = []


class FoodItemOut(FoodItemBase):
    id: int
    allergens: list[LinkedAllergenOut]
    may_contain_allergens: list[LinkedAllergenOut]

    class Config:
        from_attributes = True


class FoodItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    image_path: Optional[str] = None
    allergen_ids: Optional[list[int]] = None
    may_contain_allergen_ids: Optional[list[int]] = None


class RecipeCreate(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    allergen_ids: list[int] = []
    may_contain_allergen_ids: list[int] = []


class RecipeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    allergen_ids: Optional[list[int]] = None
    may_contain_allergen_ids: Optional[list[int]] = None


class RecipeOut(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    allergens: list[LinkedAllergenOut]
    may_contain_allergens: list[LinkedAllergenOut]

    class Config:
        from_attributes = True


class RestaurantCreate(BaseModel):
    name: str
    admin_pin: str


class RestaurantAuthOut(BaseModel):
    token: str
    restaurant_id: int
    restaurant_name: str
    join_code: str
    role: str


class RestaurantJoin(BaseModel):
    join_code: str


class AdminLogin(BaseModel):
    join_code: str
    admin_pin: str


class ScanTextRequest(BaseModel):
    text_lines: list[str]


@app.on_event("startup")
async def on_startup():
    await init_db()


@app.post("/restaurants", response_model=RestaurantAuthOut)
async def create_restaurant(data: RestaurantCreate, db: AsyncSession = Depends(get_db)):
    join_code = generate_join_code()
    restaurant = RestaurantORM(name=data.name, join_code=join_code, admin_pin_hash=hash_pin(data.admin_pin))
    db.add(restaurant)
    await db.commit()
    await db.refresh(restaurant)

    admin_user = UserORM(restaurant_id=restaurant.id, role=UserRole.admin)
    db.add(admin_user)
    await db.commit()
    await db.refresh(admin_user)

    token = create_access_token(admin_user.id, restaurant.id, UserRole.admin)
    return RestaurantAuthOut(
        token=token,
        restaurant_id=restaurant.id,
        restaurant_name=restaurant.name,
        join_code=restaurant.join_code,
        role=UserRole.admin.value,
    )


@app.post("/restaurants/join", response_model=RestaurantAuthOut)
async def join_restaurant(data: RestaurantJoin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(RestaurantORM).where(RestaurantORM.join_code == data.join_code))
    restaurant = result.scalar_one_or_none()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Invalid join code")

    staff_user = UserORM(restaurant_id=restaurant.id, role=UserRole.staff)
    db.add(staff_user)
    await db.commit()
    await db.refresh(staff_user)

    token = create_access_token(staff_user.id, restaurant.id, UserRole.staff)
    return RestaurantAuthOut(
        token=token,
        restaurant_id=restaurant.id,
        restaurant_name=restaurant.name,
        join_code=restaurant.join_code,
        role=UserRole.staff.value,
    )


@app.post("/auth/admin-login", response_model=RestaurantAuthOut)
async def admin_login(data: AdminLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(RestaurantORM).where(RestaurantORM.join_code == data.join_code))
    restaurant = result.scalar_one_or_none()
    if not restaurant or not verify_pin(data.admin_pin, restaurant.admin_pin_hash):
        raise HTTPException(status_code=401, detail="Invalid join code or admin PIN")

    result = await db.execute(
        select(UserORM).where(UserORM.restaurant_id == restaurant.id, UserORM.role == UserRole.admin).limit(1)
    )
    admin_user = result.scalar_one_or_none()
    if not admin_user:
        admin_user = UserORM(restaurant_id=restaurant.id, role=UserRole.admin)
        db.add(admin_user)
        await db.commit()
        await db.refresh(admin_user)

    token = create_access_token(admin_user.id, restaurant.id, UserRole.admin)
    return RestaurantAuthOut(
        token=token,
        restaurant_id=restaurant.id,
        restaurant_name=restaurant.name,
        join_code=restaurant.join_code,
        role=UserRole.admin.value,
    )


@app.get("/allergens", response_model=list[AllergenOut])
async def list_allergens(db: AsyncSession = Depends(get_db), user: UserORM = Depends(get_current_user)):
    result = await db.execute(select(AllergenORM).where(AllergenORM.restaurant_id == user.restaurant_id))
    return result.scalars().all()


@app.post("/allergens", response_model=AllergenOut)
async def create_allergen(
    allergen: AllergenCreate,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(require_admin),
):
    db_allergen = AllergenORM(restaurant_id=user.restaurant_id, **allergen.model_dump())
    db.add(db_allergen)
    await db.commit()
    await db.refresh(db_allergen)
    return db_allergen


def _split_allergen_links(links) -> tuple[list[dict], list[dict]]:
    allergens, may_contain = [], []
    for link in links:
        entry = {
            "id": link.allergen.id,
            "name": link.allergen.name,
            "description": link.allergen.description,
            "note": link.note,
        }
        (allergens if link.certain else may_contain).append(entry)
    return allergens, may_contain


def _serialize_food_item(item: FoodItemORM) -> dict:
    allergens, may_contain = _split_allergen_links(item.allergen_links)
    return {
        "id": item.id,
        "name": item.name,
        "description": item.description,
        "category": item.category,
        "image_path": item.image_path,
        "allergens": allergens,
        "may_contain_allergens": may_contain,
    }


def _serialize_recipe(recipe: RecipeORM) -> dict:
    allergens, may_contain = _split_allergen_links(recipe.allergen_links)
    return {
        "id": recipe.id,
        "name": recipe.name,
        "description": recipe.description,
        "category": recipe.category,
        "allergens": allergens,
        "may_contain_allergens": may_contain,
    }


async def _validate_allergen_ids(db: AsyncSession, ids: list[int], restaurant_id: int) -> list[int]:
    if not ids:
        return []
    result = await db.execute(
        select(AllergenORM.id).where(AllergenORM.id.in_(ids), AllergenORM.restaurant_id == restaurant_id)
    )
    return list(result.scalars().all())


@app.get("/food-items", response_model=list[FoodItemOut])
async def list_food_items(db: AsyncSession = Depends(get_db), user: UserORM = Depends(get_current_user)):
    result = await db.execute(
        select(FoodItemORM)
        .where(FoodItemORM.restaurant_id == user.restaurant_id)
        .options(selectinload(FoodItemORM.allergen_links).selectinload(FoodItemAllergenORM.allergen))
    )
    return [_serialize_food_item(item) for item in result.scalars().all()]


@app.get("/food-items/suggest")
async def suggest_food_items(
    q: str = "",
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(get_current_user),
):
    if not q:
        return []
    items_result = await db.execute(
        select(FoodItemORM)
        .where(FoodItemORM.restaurant_id == user.restaurant_id, FoodItemORM.name.ilike(f"%{q}%"))
        .limit(10)
    )
    items = items_result.scalars().all()
    recipes_result = await db.execute(
        select(RecipeORM)
        .where(RecipeORM.restaurant_id == user.restaurant_id, RecipeORM.name.ilike(f"%{q}%"))
        .limit(10)
    )
    recipes = recipes_result.scalars().all()
    return {
        "items": [{"id": item.id, "name": item.name, "category": item.category} for item in items],
        "recipes": [{"id": r.id, "name": r.name, "category": r.category, "type": "recipe"} for r in recipes],
    }


@app.get("/recipes", response_model=list[RecipeOut])
async def list_recipes(db: AsyncSession = Depends(get_db), user: UserORM = Depends(get_current_user)):
    result = await db.execute(
        select(RecipeORM)
        .where(RecipeORM.restaurant_id == user.restaurant_id)
        .options(selectinload(RecipeORM.allergen_links).selectinload(RecipeAllergenORM.allergen))
    )
    return [_serialize_recipe(r) for r in result.scalars().all()]


@app.post("/recipes", response_model=RecipeOut)
async def create_recipe(
    recipe: RecipeCreate,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(require_admin),
):
    db_recipe = RecipeORM(
        restaurant_id=user.restaurant_id,
        name=recipe.name,
        description=recipe.description,
        category=recipe.category,
    )
    contains_ids = await _validate_allergen_ids(db, recipe.allergen_ids, user.restaurant_id)
    mc_ids = await _validate_allergen_ids(db, recipe.may_contain_allergen_ids, user.restaurant_id)
    db_recipe.allergen_links = [
        RecipeAllergenORM(allergen_id=aid, certain=True) for aid in contains_ids
    ] + [
        RecipeAllergenORM(allergen_id=aid, certain=False) for aid in mc_ids
    ]
    db.add(db_recipe)
    await db.commit()
    await db.refresh(db_recipe, ["allergen_links"])
    for link in db_recipe.allergen_links:
        await db.refresh(link, ["allergen"])
    return _serialize_recipe(db_recipe)


@app.put("/recipes/{recipe_id}", response_model=RecipeOut)
async def update_recipe(
    recipe_id: int,
    data: RecipeUpdate,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(require_admin),
):
    result = await db.execute(
        select(RecipeORM)
        .where(RecipeORM.id == recipe_id, RecipeORM.restaurant_id == user.restaurant_id)
        .options(selectinload(RecipeORM.allergen_links).selectinload(RecipeAllergenORM.allergen))
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if data.name is not None:
        recipe.name = data.name
    if data.description is not None:
        recipe.description = data.description
    if data.category is not None:
        recipe.category = data.category
    if data.allergen_ids is not None or data.may_contain_allergen_ids is not None:
        new_contains = (
            data.allergen_ids
            if data.allergen_ids is not None
            else [link.allergen_id for link in recipe.allergen_links if link.certain]
        )
        new_may_contain = (
            data.may_contain_allergen_ids
            if data.may_contain_allergen_ids is not None
            else [link.allergen_id for link in recipe.allergen_links if not link.certain]
        )
        contains_ids = await _validate_allergen_ids(db, new_contains, user.restaurant_id)
        mc_ids = await _validate_allergen_ids(db, new_may_contain, user.restaurant_id)
        recipe.allergen_links = [
            RecipeAllergenORM(allergen_id=aid, certain=True) for aid in contains_ids
        ] + [
            RecipeAllergenORM(allergen_id=aid, certain=False) for aid in mc_ids
        ]
    await db.commit()
    await db.refresh(recipe, ["allergen_links"])
    for link in recipe.allergen_links:
        await db.refresh(link, ["allergen"])
    return _serialize_recipe(recipe)


@app.get("/recipes/{recipe_id}", response_model=RecipeOut)
async def read_recipe(
    recipe_id: int,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(get_current_user),
):
    result = await db.execute(
        select(RecipeORM)
        .where(RecipeORM.id == recipe_id, RecipeORM.restaurant_id == user.restaurant_id)
        .options(selectinload(RecipeORM.allergen_links).selectinload(RecipeAllergenORM.allergen))
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return _serialize_recipe(recipe)


@app.delete("/recipes/{recipe_id}")
async def delete_recipe(
    recipe_id: int,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(require_admin),
):
    result = await db.execute(
        select(RecipeORM).where(RecipeORM.id == recipe_id, RecipeORM.restaurant_id == user.restaurant_id)
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    await db.delete(recipe)
    await db.commit()
    return {"detail": "Recipe deleted"}


@app.get("/food-items/{item_id}", response_model=FoodItemOut)
async def read_food_item(
    item_id: int,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(get_current_user),
):
    result = await db.execute(
        select(FoodItemORM)
        .where(FoodItemORM.id == item_id, FoodItemORM.restaurant_id == user.restaurant_id)
        .options(selectinload(FoodItemORM.allergen_links).selectinload(FoodItemAllergenORM.allergen))
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Food item not found")
    return _serialize_food_item(item)


@app.put("/food-items/{item_id}", response_model=FoodItemOut)
async def update_food_item(
    item_id: int,
    food: FoodItemUpdate,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(require_admin),
):
    result = await db.execute(
        select(FoodItemORM)
        .where(FoodItemORM.id == item_id, FoodItemORM.restaurant_id == user.restaurant_id)
        .options(selectinload(FoodItemORM.allergen_links).selectinload(FoodItemAllergenORM.allergen))
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
    if food.allergen_ids is not None or food.may_contain_allergen_ids is not None:
        new_contains = (
            food.allergen_ids
            if food.allergen_ids is not None
            else [link.allergen_id for link in db_food.allergen_links if link.certain]
        )
        new_may_contain = (
            food.may_contain_allergen_ids
            if food.may_contain_allergen_ids is not None
            else [link.allergen_id for link in db_food.allergen_links if not link.certain]
        )
        contains_ids = await _validate_allergen_ids(db, new_contains, user.restaurant_id)
        mc_ids = await _validate_allergen_ids(db, new_may_contain, user.restaurant_id)
        db_food.allergen_links = [
            FoodItemAllergenORM(allergen_id=aid, certain=True) for aid in contains_ids
        ] + [
            FoodItemAllergenORM(allergen_id=aid, certain=False) for aid in mc_ids
        ]

    await db.commit()
    await db.refresh(db_food, ["allergen_links"])
    for link in db_food.allergen_links:
        await db.refresh(link, ["allergen"])
    return _serialize_food_item(db_food)


@app.post("/food-items", response_model=FoodItemOut)
async def create_food_item(
    food: FoodItemCreate,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(require_admin),
):
    db_food = FoodItemORM(
        restaurant_id=user.restaurant_id,
        name=food.name,
        description=food.description,
        category=food.category,
        image_path=food.image_path,
    )
    contains_ids = await _validate_allergen_ids(db, food.allergen_ids, user.restaurant_id)
    mc_ids = await _validate_allergen_ids(db, food.may_contain_allergen_ids, user.restaurant_id)
    db_food.allergen_links = [
        FoodItemAllergenORM(allergen_id=aid, certain=True) for aid in contains_ids
    ] + [
        FoodItemAllergenORM(allergen_id=aid, certain=False) for aid in mc_ids
    ]
    db.add(db_food)
    await db.commit()
    await db.refresh(db_food, ["allergen_links"])
    for link in db_food.allergen_links:
        await db.refresh(link, ["allergen"])
    return _serialize_food_item(db_food)


@app.delete("/food-items/{item_id}")
async def delete_food_item(
    item_id: int,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(require_admin),
):
    result = await db.execute(
        select(FoodItemORM).where(FoodItemORM.id == item_id, FoodItemORM.restaurant_id == user.restaurant_id)
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
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(get_current_user),
):
    if ocr_service is None:
        raise HTTPException(
            status_code=501,
            detail="Server-side image scanning is not available on this deployment; use /scan/text instead.",
        )
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

    detected, known = await _match_allergens(db, user.restaurant_id, text_lines)

    return {
        "image_path": f"/uploads/{filename}",
        "detected_allergens": detected,
        "all_allergens": known,
    }


@app.post("/scan/text")
async def scan_text(
    data: ScanTextRequest,
    db: AsyncSession = Depends(get_db),
    user: UserORM = Depends(get_current_user),
):
    """Match allergens against text already extracted on-device (e.g. by Apple Vision on iOS)."""
    detected, known = await _match_allergens(db, user.restaurant_id, data.text_lines)
    return {
        "detected_allergens": detected,
        "all_allergens": known,
    }


async def _match_allergens(db: AsyncSession, restaurant_id: int, text_lines: list[str]):
    result = await db.execute(select(AllergenORM).where(AllergenORM.restaurant_id == restaurant_id))
    known_allergens = result.scalars().all()
    known_names = [a.name for a in known_allergens]

    found_names = find_allergens_in_text(text_lines, known_names)

    detected = [{"id": a.id, "name": a.name} for a in known_allergens if a.name in found_names]
    known = [{"id": a.id, "name": a.name} for a in known_allergens]
    return detected, known


app.mount("/uploads", StaticFiles(directory="static/uploads"), name="uploads")
app.mount("/static", StaticFiles(directory="frontend/dist", html=True), name="static")


@app.get("/")
async def serve_index():
    return RedirectResponse(url="/static/")


@app.get("/health")
async def health_check():
    return {"status": "ok"}
