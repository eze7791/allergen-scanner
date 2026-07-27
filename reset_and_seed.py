import asyncio
from sqlalchemy import text
from database import engine, init_db, async_session
from models import RestaurantORM, UserORM, UserRole
from auth import hash_pin, generate_join_code
from seed_allergens import seed_allergens

DEMO_RESTAURANT_NAME = "Demo Restaurant"
DEMO_ADMIN_USERNAME = "demo_admin"
DEMO_ADMIN_PASSWORD = "demo1234"


async def reset():
    await init_db()
    async with engine.begin() as conn:
        await conn.execute(text(
            "TRUNCATE TABLE food_item_allergens, recipe_allergens, food_items, "
            "recipes, allergens, users, restaurants RESTART IDENTITY CASCADE"
        ))
    print("Tables truncated.")

    async with async_session() as db:
        restaurant = RestaurantORM(
            name=DEMO_RESTAURANT_NAME,
            join_code=generate_join_code(),
        )
        db.add(restaurant)
        await db.commit()
        await db.refresh(restaurant)

        admin = UserORM(
            restaurant_id=restaurant.id,
            role=UserRole.admin,
            username=DEMO_ADMIN_USERNAME,
            password_hash=hash_pin(DEMO_ADMIN_PASSWORD),
        )
        db.add(admin)
        await db.commit()

    print(
        f"Demo restaurant created: id={restaurant.id} join_code={restaurant.join_code} "
        f"admin_username={DEMO_ADMIN_USERNAME} admin_password={DEMO_ADMIN_PASSWORD}"
    )

    await seed_allergens(restaurant.id)
    await engine.dispose()

asyncio.run(reset())
