import uuid
from datetime import datetime

from pydantic import BaseModel


class BranchCreate(BaseModel):
    name: str
    code: str
    address: str | None = None


class BranchUpdate(BaseModel):
    name: str | None = None
    address: str | None = None


class BranchResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    name: str
    code: str
    address: str | None
    sync_cursor: str | None
    last_synced_at: datetime | None
    created_at: datetime
