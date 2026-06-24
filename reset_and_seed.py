import asyncio
from sqlalchemy import text
from database import engine, init_db
from seed_allergens import seed_allergens

async def reset():
    await init_db()
    async with engine.begin() as conn:
        await conn.execute(text("TRUNCATE TABLE food_allergen_association, food_items, allergens RESTART IDENTITY CASCADE"))
    print("Tables truncated.")
    await seed_allergens()
    await engine.dispose()

asyncio.run(reset())
