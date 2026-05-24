import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class MutationStatus(str, enum.Enum):
    pending = "pending"
    processing = "processing"
    synced = "synced"
    failed = "failed"
    conflict = "conflict"


class MutationOperation(str, enum.Enum):
    create = "create"
    update = "update"
    delete = "delete"


class SyncMutation(Base):
    __tablename__ = "sync_mutations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    device_id: Mapped[str] = mapped_column(String(100), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(50), nullable=False)
    entity_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    operation: Mapped[MutationOperation] = mapped_column(Enum(MutationOperation), nullable=False)
    payload_json: Mapped[str] = mapped_column(Text, nullable=False)
    base_version: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[MutationStatus] = mapped_column(Enum(MutationStatus), default=MutationStatus.pending)
    retry_count: Mapped[int] = mapped_column(Integer, default=0)
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
