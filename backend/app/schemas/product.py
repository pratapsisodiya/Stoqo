import uuid
from datetime import datetime

from pydantic import BaseModel


class ProductCreate(BaseModel):
    branch_id: uuid.UUID
    sku: str
    barcode: str | None = None
    name: str
    category: str | None = None
    unit: str = "pcs"
    cost_price: float = 0
    selling_price: float = 0
    min_stock_level: int = 0
    notes: str | None = None
    device_id: str | None = None


class ProductUpdate(BaseModel):
    sku: str | None = None
    barcode: str | None = None
    name: str | None = None
    category: str | None = None
    unit: str | None = None
    cost_price: float | None = None
    selling_price: float | None = None
    min_stock_level: int | None = None
    notes: str | None = None


class ProductResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    branch_id: uuid.UUID
    sku: str
    barcode: str | None
    name: str
    category: str | None
    unit: str
    cost_price: float
    selling_price: float
    min_stock_level: int
    current_quantity: int
    version: int
    notes: str | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
