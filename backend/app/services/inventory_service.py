import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.movement import InventoryMovement, MovementType
from app.models.product import Product
from app.repositories.movement import MovementRepository
from app.repositories.product import ProductRepository
from app.schemas.movement import MovementCreate


class InventoryService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.product_repo = ProductRepository(db)
        self.movement_repo = MovementRepository(db)

    async def apply_movement(self, data: MovementCreate, created_by: uuid.UUID | None) -> InventoryMovement:
        product = await self.product_repo.get(data.product_id)
        if not product or product.deleted_at is not None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found or deleted")

        if data.mutation_id:
            existing = await self.movement_repo.get_by_mutation_id(data.mutation_id)
            if existing:
                return existing

        qty_before = product.current_quantity
        delta = self._resolve_delta(data.type, data.quantity)
        qty_after = qty_before + delta

        movement = InventoryMovement(
            id=data.mutation_id or uuid.uuid4(),
            product_id=data.product_id,
            branch_id=data.branch_id,
            type=data.type,
            quantity=data.quantity,
            quantity_before=qty_before,
            quantity_after=qty_after,
            reason=data.reason,
            reference_type=data.reference_type,
            reference_id=data.reference_id,
            created_by=created_by,
            device_id=data.device_id,
            mutation_id=data.mutation_id,
        )

        product.current_quantity = qty_after
        product.version += 1
        product.updated_at = datetime.now(timezone.utc)

        self.db.add(movement)
        await self.db.flush()
        await self.db.refresh(movement)
        return movement

    def _resolve_delta(self, movement_type: MovementType, quantity: int) -> int:
        positive = {MovementType.stock_in, MovementType.transfer_in, MovementType.purchase, MovementType.return_}
        negative = {MovementType.stock_out, MovementType.transfer_out, MovementType.sale}
        if movement_type in positive:
            return quantity
        if movement_type in negative:
            return -quantity
        return quantity  # adjustment uses signed quantity directly
