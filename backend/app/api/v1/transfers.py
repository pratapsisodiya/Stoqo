import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.transfer import Transfer
from app.models.user import User
from app.schemas.transfer import TransferCreate, TransferReceive, TransferResponse
from app.services.transfer_service import TransferService

router = APIRouter(prefix="/transfers", tags=["transfers"])


async def _get_transfer_with_items(db: AsyncSession, transfer_id: uuid.UUID) -> Transfer:
    result = await db.execute(
        select(Transfer).where(Transfer.id == transfer_id).options(selectinload(Transfer.items))
    )
    transfer = result.scalar_one_or_none()
    if not transfer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer not found")
    return transfer


@router.post("", response_model=TransferResponse, status_code=201)
async def create_transfer(
    body: TransferCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    transfer = await TransferService(db).create(body, current_user.id)
    return await _get_transfer_with_items(db, transfer.id)


@router.patch("/{transfer_id}/approve", response_model=TransferResponse)
async def approve_transfer(
    transfer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    transfer = await _get_transfer_with_items(db, transfer_id)
    transfer = await TransferService(db).approve(transfer, current_user.id)
    return await _get_transfer_with_items(db, transfer.id)


@router.patch("/{transfer_id}/receive", response_model=TransferResponse)
async def receive_transfer(
    transfer_id: uuid.UUID,
    body: TransferReceive,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    transfer = await _get_transfer_with_items(db, transfer_id)
    transfer = await TransferService(db).receive(transfer, current_user.id, body.items)
    return await _get_transfer_with_items(db, transfer.id)


@router.get("", response_model=list[TransferResponse])
async def list_transfers(
    branch_id: uuid.UUID = Query(...),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Transfer)
        .where((Transfer.from_branch_id == branch_id) | (Transfer.to_branch_id == branch_id))
        .options(selectinload(Transfer.items))
        .order_by(Transfer.created_at.desc())
    )
    return list(result.scalars().all())
