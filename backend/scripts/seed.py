"""
Seed the database with 2 branches, 1 admin, 2 staff users,
50 products, sample movements, and sample alerts.

Run: uv run python scripts/seed.py
"""
import asyncio
import random
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password
from app.models.alert import Alert, AlertType
from app.models.branch import Branch
from app.models.movement import InventoryMovement, MovementType
from app.models.product import Product
from app.models.user import User, UserRole

CATEGORIES = ["Beverages", "Snacks", "Dairy", "Cleaning", "Personal Care", "Stationery", "Electronics", "Hardware"]
UNITS = ["pcs", "kg", "ltr", "box", "pack", "roll"]

PRODUCT_NAMES = [
    "Mineral Water 600ml", "Orange Juice 1L", "Coffee Powder 250g", "Green Tea 25s",
    "Chocolate Bar 100g", "Potato Chips 150g", "Crackers Assorted", "Instant Noodles",
    "Full Cream Milk 1L", "Yogurt Strawberry 125g", "Cheese Slice 10s", "Butter 200g",
    "Floor Cleaner 500ml", "Dishwash Liquid 500ml", "Laundry Powder 1kg", "Toilet Bowl Cleaner",
    "Shampoo 200ml", "Conditioner 200ml", "Toothpaste 120g", "Hand Soap 250ml",
    "Ballpoint Pen Blue", "A4 Paper 80gsm Ream", "Sticky Notes 3x3", "Stapler",
    "USB Flash Drive 32GB", "Phone Cable 1m", "Power Bank 10000mAh", "Earphones",
    "Hammer 500g", "Screwdriver Set", "Duct Tape 50m", "Cable Ties 100s",
    "Instant Coffee 3in1", "Sugar 1kg", "Salt 500g", "Cooking Oil 1L",
    "Basmati Rice 5kg", "Sardines Can 425g", "Tomato Paste 200g", "Soy Sauce 200ml",
    "Eggs 10s Tray", "Frozen Chicken 1kg", "Fish Fillet 500g", "Mixed Vegetables 500g",
    "Bleach 1L", "Air Freshener 300ml", "Mosquito Coil 10s", "Garbage Bags 10s",
    "Notebook A5", "Correction Tape",
]


async def seed(db: AsyncSession) -> None:
    print("Seeding branches...")
    branch_main = Branch(id=uuid.uuid4(), name="Main Warehouse", code="MAIN", address="123 Industrial Ave")
    branch_retail = Branch(id=uuid.uuid4(), name="Downtown Retail", code="DTOWN", address="45 Market Street")
    db.add_all([branch_main, branch_retail])
    await db.flush()

    print("Seeding users...")
    admin = User(
        id=uuid.uuid4(),
        name="Admin User",
        email="admin@stoqo.com",
        hashed_password=hash_password("admin1234"),
        role=UserRole.admin,
        branch_id=branch_main.id,
    )
    staff_main = User(
        id=uuid.uuid4(),
        name="Staff Main",
        phone="+628001234001",
        hashed_password=hash_password("staff1234"),
        role=UserRole.staff,
        branch_id=branch_main.id,
    )
    staff_retail = User(
        id=uuid.uuid4(),
        name="Staff Retail",
        phone="+628001234002",
        hashed_password=hash_password("staff1234"),
        role=UserRole.staff,
        branch_id=branch_retail.id,
    )
    db.add_all([admin, staff_main, staff_retail])
    await db.flush()

    print("Seeding products (50 per branch)...")
    branches = [branch_main, branch_retail]
    all_products: list[Product] = []

    for branch in branches:
        for i, name in enumerate(PRODUCT_NAMES):
            initial_qty = random.randint(0, 200)
            min_level = random.randint(5, 30)
            product = Product(
                id=uuid.uuid4(),
                branch_id=branch.id,
                sku=f"SKU-{branch.code}-{i+1:03d}",
                barcode=f"8{branch.code}{i+1:07d}",
                name=name,
                category=random.choice(CATEGORIES),
                unit=random.choice(UNITS),
                cost_price=round(random.uniform(1.5, 50.0), 2),
                selling_price=round(random.uniform(2.0, 80.0), 2),
                min_stock_level=min_level,
                current_quantity=initial_qty,
                version=1,
            )
            db.add(product)
            all_products.append(product)

    await db.flush()

    print("Seeding inventory movements (sample)...")
    movement_types = [MovementType.stock_in, MovementType.stock_out, MovementType.sale]
    for product in random.sample(all_products, min(40, len(all_products))):
        for _ in range(random.randint(1, 5)):
            mtype = random.choice(movement_types)
            qty = random.randint(1, 20)
            movement = InventoryMovement(
                id=uuid.uuid4(),
                product_id=product.id,
                branch_id=product.branch_id,
                type=mtype,
                quantity=qty,
                quantity_before=product.current_quantity,
                quantity_after=product.current_quantity + (qty if mtype == MovementType.stock_in else -qty),
                reason="seed data",
                created_by=admin.id,
                created_at=datetime.now(timezone.utc) - timedelta(days=random.randint(0, 30)),
                mutation_id=uuid.uuid4(),
            )
            db.add(movement)

    await db.flush()

    print("Seeding low-stock alerts...")
    low_products = [p for p in all_products if p.current_quantity <= p.min_stock_level][:10]
    for product in low_products:
        alert_type = AlertType.out_of_stock if product.current_quantity <= 0 else AlertType.low_stock
        alert = Alert(
            branch_id=product.branch_id,
            product_id=product.id,
            type=alert_type,
            message=f"'{product.name}' is low on stock: {product.current_quantity} left (min {product.min_stock_level}).",
        )
        db.add(alert)

    await db.commit()
    print("\nSeed complete!")
    print(f"  Branches: {branch_main.code}, {branch_retail.code}")
    print(f"  Admin: admin@stoqo.com / admin1234")
    print(f"  Staff: {staff_main.phone} / staff1234")
    print(f"  Products seeded: {len(all_products)}")
    print(f"  Low-stock alerts: {len(low_products)}")


async def main() -> None:
    async with AsyncSessionLocal() as db:
        await seed(db)


if __name__ == "__main__":
    asyncio.run(main())
