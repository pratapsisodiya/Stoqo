import uuid
from datetime import datetime

from pydantic import BaseModel

from app.models.transfer import TransferStatus


class TransferItemCreate(BaseModel):
    product_id: uuid.UUID
    quantity: int


class TransferCreate(BaseModel):
    from_branch_id: uuid.UUID
    to_branch_id: uuid.UUID
    notes: str | None = None
    items: list[TransferItemCreate]


class TransferReceive(BaseModel):
    items: list[dict]  # [{transfer_item_id, received_quantity}]


class TransferItemResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    product_id: uuid.UUID
    quantity: int
    received_quantity: int | None


class TransferResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    from_branch_id: uuid.UUID
    to_branch_id: uuid.UUID
    status: TransferStatus
    notes: str | None
    created_by: uuid.UUID | None
    approved_by: uuid.UUID | None
    created_at: datetime
    approved_at: datetime | None
    received_at: datetime | None
    items: list[TransferItemResponse] = []
