import uuid

from sqlalchemy import or_, select

from app.models.product import Product
from app.repositories.base import BaseRepository


class ProductRepository(BaseRepository[Product]):
    model = Product

    async def search(self, branch_id: uuid.UUID, q: str) -> list[Product]:
        pattern = f"%{q}%"
        result = await self.db.execute(
            select(Product).where(
                Product.branch_id == branch_id,
                Product.deleted_at.is_(None),
                or_(
                    Product.name.ilike(pattern),
                    Product.sku.ilike(pattern),
                    Product.barcode.ilike(pattern),
                ),
            )
        )
        return list(result.scalars().all())

    async def get_by_barcode(self, branch_id: uuid.UUID, barcode: str) -> Product | None:
        result = await self.db.execute(
            select(Product).where(
                Product.branch_id == branch_id,
                Product.barcode == barcode,
                Product.deleted_at.is_(None),
            )
        )
        return result.scalar_one_or_none()

    async def list_active(self, branch_id: uuid.UUID) -> list[Product]:
        result = await self.db.execute(
            select(Product).where(Product.branch_id == branch_id, Product.deleted_at.is_(None))
        )
        return list(result.scalars().all())

    async def list_low_stock(self, branch_id: uuid.UUID) -> list[Product]:
        result = await self.db.execute(
            select(Product).where(
                Product.branch_id == branch_id,
                Product.deleted_at.is_(None),
                Product.current_quantity <= Product.min_stock_level,
            )
        )
        return list(result.scalars().all())
