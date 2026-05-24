import uuid
from datetime import date, datetime

from pydantic import BaseModel


class PurchaseItemCreate(BaseModel):
    product_id: uuid.UUID
    quantity: int
    unit_cost: float


class PurchaseCreate(BaseModel):
    branch_id: uuid.UUID
    supplier_name: str | None = None
    invoice_number: str | None = None
    total_amount: float = 0
    purchase_date: date
    items: list[PurchaseItemCreate]


class PurchaseItemResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    product_id: uuid.UUID
    quantity: int
    unit_cost: float


class PurchaseResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    branch_id: uuid.UUID
    supplier_name: str | None
    invoice_number: str | None
    total_amount: float
    purchase_date: date
    created_by: uuid.UUID | None
    created_at: datetime
    items: list[PurchaseItemResponse] = []
