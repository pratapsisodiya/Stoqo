import uuid
from datetime import datetime

from pydantic import BaseModel


class ConflictResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    entity_type: str
    entity_id: uuid.UUID
    local_version: int | None
    server_version: int | None
    conflict_type: str
    resolution_strategy: str | None
    mutation_id: uuid.UUID | None
    resolved_at: datetime | None
    created_at: datetime
