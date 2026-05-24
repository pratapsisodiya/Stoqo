import uuid
from datetime import datetime

from pydantic import BaseModel

from app.models.movement import MovementType


class MovementCreate(BaseModel):
    product_id: uuid.UUID
    branch_id: uuid.UUID
    type: MovementType
    quantity: int
    reason: str | None = None
    reference_type: str | None = None
    reference_id: uuid.UUID | None = None
    device_id: str | None = None
    mutation_id: uuid.UUID | None = None


class MovementResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    product_id: uuid.UUID
    branch_id: uuid.UUID
    type: MovementType
    quantity: int
    quantity_before: int
    quantity_after: int
    reason: str | None
    reference_type: str | None
    reference_id: uuid.UUID | None
    created_by: uuid.UUID | None
    created_at: datetime
    device_id: str | None
    mutation_id: uuid.UUID | None
