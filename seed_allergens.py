import asyncio
from sqlalchemy import select
from database import async_session, init_db
from models import AllergenORM

# The 14 allergens mandated by EU Regulation 1169/2011 (Food Information to
# Consumers), enforced in Ireland via the Health (Provision of Food Allergen
# Information to Consumers in Respect of Non-Prepacked Food) Regulations 2014
# and the FSAI. These are the legally required allergens for any Irish
# restaurant menu, whether the food is prepacked or not.
COMMON_ALLERGENS = [
    ("Cereals containing gluten", "Wheat (including spelt and khorasan wheat), rye, barley, oats"),
    ("Crustaceans", "Crabs, prawns, lobsters"),
    ("Eggs", "Eggs and egg-derived products"),
    ("Fish", "Fish and fish-derived products"),
    ("Peanuts", "Peanuts and peanut-derived products"),
    ("Soybeans", "Soybeans and soy-derived products"),
    ("Milk", "Milk and milk-derived products (including lactose)"),
    ("Nuts", "Almonds, hazelnuts, walnuts, cashews, pecan nuts, brazil nuts, pistachio nuts, macadamia/Queensland nuts"),
    ("Celery", "Celery and celery-derived products"),
    ("Mustard", "Mustard and mustard-derived products"),
    ("Sesame seeds", "Sesame seeds and sesame-derived products"),
    ("Sulphur dioxide and sulphites", "At concentrations of more than 10 mg/kg or 10 mg/L in terms of total SO2"),
    ("Lupin", "Lupin and lupin-derived products"),
    ("Molluscs", "Mussels, oysters, squid, snails"),
]


async def seed_allergens(restaurant_id: int):
    async with async_session() as db:
        result = await db.execute(select(AllergenORM).where(AllergenORM.restaurant_id == restaurant_id))
        existing = {a.name for a in result.scalars().all()}

        new_count = 0
        for name, desc in COMMON_ALLERGENS:
            if name not in existing:
                allergen = AllergenORM(restaurant_id=restaurant_id, name=name, description=desc)
                db.add(allergen)
                new_count += 1

        if new_count > 0:
            await db.commit()
            print(f"Inserted {new_count} new allergens.")
        else:
            print("Allergens already seeded.")

        # Count total
        result = await db.execute(select(AllergenORM).where(AllergenORM.restaurant_id == restaurant_id))
        total = len(result.scalars().all())
        print(f"Total allergens in database: {total}")

if __name__ == "__main__":
    import sys
    rid = int(sys.argv[1]) if len(sys.argv) > 1 else None
    if rid is None:
        raise SystemExit("Usage: python seed_allergens.py <restaurant_id>")
    asyncio.run(seed_allergens(rid))
