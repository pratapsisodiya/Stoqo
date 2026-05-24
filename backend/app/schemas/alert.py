import uuid
from datetime import datetime

from pydantic import BaseModel

from app.models.alert import AlertType


class AlertResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    branch_id: uuid.UUID
    product_id: uuid.UUID | None
    type: AlertType
    message: str
    is_read: bool
    created_at: datetime
