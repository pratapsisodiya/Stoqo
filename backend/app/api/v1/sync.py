import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.sync import PullResponse, PushRequest, PushResponse
from app.services.sync_service import SyncService

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push", response_model=PushResponse)
async def push_mutations(
    body: PushRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return await SyncService(db).push(body.device_id, body.mutations)


@router.get("/pull", response_model=PullResponse)
async def pull_delta(
    branch_id: uuid.UUID = Query(...),
    cursor: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return await SyncService(db).pull(branch_id, cursor)


@router.get("/status")
async def sync_status(
    branch_id: uuid.UUID = Query(...),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    from sqlalchemy import func, select
    from app.models.branch import Branch
    from app.models.sync import SyncMutation, MutationStatus

    branch = await db.get(Branch, branch_id)
    pending_count_result = await db.execute(
        select(func.count()).select_from(SyncMutation).where(SyncMutation.status == MutationStatus.pending)
    )
    pending_count = pending_count_result.scalar() or 0
    return {
        "branch_id": branch_id,
        "last_synced_at": branch.last_synced_at if branch else None,
        "cursor": branch.sync_cursor if branch else None,
        "pending_count": pending_count,
    }
