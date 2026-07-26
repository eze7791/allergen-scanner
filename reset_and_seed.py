import asyncio
from sqlalchemy import text
from database import engine, init_db, async_session
from models import RestaurantORM, UserORM, UserRole
from auth import hash_pin, generate_join_code
from seed_allergens import seed_allergens

DEMO_RESTAURANT_NAME = "Demo Restaurant"
DEMO_ADMIN_PIN = "1234"


async def reset():
    await init_db()
    async with engine.begin() as conn:
        await conn.execute(text(
            "TRUNCATE TABLE food_allergen_association, recipe_items, food_items, "
            "recipes, allergens, users, restaurants RESTART IDENTITY CASCADE"
        ))
    print("Tables truncated.")

    async with async_session() as db:
        restaurant = RestaurantORM(
            name=DEMO_RESTAURANT_NAME,
            join_code=generate_join_code(),
            admin_pin_hash=hash_pin(DEMO_ADMIN_PIN),
        )
        db.add(restaurant)
        await db.commit()
        await db.refresh(restaurant)

        admin = UserORM(restaurant_id=restaurant.id, role=UserRole.admin)
        db.add(admin)
        await db.commit()

    print(f"Demo restaurant created: id={restaurant.id} join_code={restaurant.join_code} admin_pin={DEMO_ADMIN_PIN}")

    await seed_allergens(restaurant.id)
    await engine.dispose()

asyncio.run(reset())
