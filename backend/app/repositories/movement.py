import uuid

from sqlalchemy import select

from app.models.movement import InventoryMovement
from app.repositories.base import BaseRepository


class MovementRepository(BaseRepository[InventoryMovement]):
    model = InventoryMovement

    async def list_for_product(self, product_id: uuid.UUID, limit: int = 50) -> list[InventoryMovement]:
        result = await self.db.execute(
            select(InventoryMovement)
            .where(InventoryMovement.product_id == product_id)
            .order_by(InventoryMovement.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def list_for_branch(
        self, branch_id: uuid.UUID, limit: int = 100, offset: int = 0
    ) -> list[InventoryMovement]:
        result = await self.db.execute(
            select(InventoryMovement)
            .where(InventoryMovement.branch_id == branch_id)
            .order_by(InventoryMovement.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all())

    async def get_by_mutation_id(self, mutation_id: uuid.UUID) -> InventoryMovement | None:
        result = await self.db.execute(
            select(InventoryMovement).where(InventoryMovement.mutation_id == mutation_id)
        )
        return result.scalar_one_or_none()
