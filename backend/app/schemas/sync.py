import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel

from app.models.sync import MutationOperation, MutationStatus


class MutationPayload(BaseModel):
    mutation_id: uuid.UUID
    idempotency_key: str
    entity_type: str
    entity_id: uuid.UUID
    operation: MutationOperation
    base_version: int | None = None
    payload: dict[str, Any]


class PushRequest(BaseModel):
    device_id: str
    mutations: list[MutationPayload]


class MutationResult(BaseModel):
    mutation_id: uuid.UUID
    status: MutationStatus
    conflict_type: str | None = None
    conflict_detail: dict[str, Any] | None = None
    server_version: int | None = None


class PushResponse(BaseModel):
    accepted: list[MutationResult] = []
    conflicted: list[MutationResult] = []
    failed: list[MutationResult] = []


class PullResponse(BaseModel):
    products: list[dict[str, Any]] = []
    movements: list[dict[str, Any]] = []
    alerts: list[dict[str, Any]] = []
    transfers: list[dict[str, Any]] = []
    deleted_ids: list[uuid.UUID] = []
    next_cursor: str
    synced_at: datetime


class SyncStatusResponse(BaseModel):
    branch_id: uuid.UUID
    last_synced_at: datetime | None
    cursor: str | None
    pending_count: int
