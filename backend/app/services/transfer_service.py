import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.movement import MovementType
from app.models.transfer import Transfer, TransferItem, TransferStatus
from app.repositories.product import ProductRepository
from app.schemas.movement import MovementCreate
from app.schemas.transfer import TransferCreate
from app.services.inventory_service import InventoryService


class TransferService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.inventory = InventoryService(db)
        self.product_repo = ProductRepository(db)

    async def create(self, data: TransferCreate, created_by: uuid.UUID | None) -> Transfer:
        transfer = Transfer(
            from_branch_id=data.from_branch_id,
            to_branch_id=data.to_branch_id,
            notes=data.notes,
            created_by=created_by,
        )
        self.db.add(transfer)
        await self.db.flush()

        for item_data in data.items:
            item = TransferItem(
                transfer_id=transfer.id,
                product_id=item_data.product_id,
                quantity=item_data.quantity,
            )
            self.db.add(item)

        await self.db.flush()
        await self.db.refresh(transfer)
        return transfer

    async def approve(self, transfer: Transfer, approved_by: uuid.UUID) -> Transfer:
        if transfer.status != TransferStatus.pending:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Transfer is not pending")

        for item in transfer.items:
            await self.inventory.apply_movement(
                MovementCreate(
                    product_id=item.product_id,
                    branch_id=transfer.from_branch_id,
                    type=MovementType.transfer_out,
                    quantity=item.quantity,
                    reference_type="transfer",
                    reference_id=transfer.id,
                ),
                created_by=approved_by,
            )

        transfer.status = TransferStatus.approved
        transfer.approved_by = approved_by
        transfer.approved_at = datetime.now(timezone.utc)
        await self.db.flush()
        return transfer

    async def receive(self, transfer: Transfer, received_by: uuid.UUID, items_received: list[dict]) -> Transfer:
        if transfer.status != TransferStatus.approved:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Transfer not approved yet")

        received_map = {str(r["transfer_item_id"]): r["received_quantity"] for r in items_received}

        for item in transfer.items:
            qty = received_map.get(str(item.id), item.quantity)
            item.received_quantity = qty
            await self.inventory.apply_movement(
                MovementCreate(
                    product_id=item.product_id,
                    branch_id=transfer.to_branch_id,
                    type=MovementType.transfer_in,
                    quantity=qty,
                    reference_type="transfer",
                    reference_id=transfer.id,
                ),
                created_by=received_by,
            )

        transfer.status = TransferStatus.received
        transfer.received_at = datetime.now(timezone.utc)
        await self.db.flush()
        return transfer
