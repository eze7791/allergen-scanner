import asyncio
from database import init_db

# Import models to register them with Base.metadata before creating tables
import main  # noqa: F401

async def create_tables():
    await init_db()
    print("Database tables created successfully.")

if __name__ == "__main__":
    asyncio.run(create_tables())
