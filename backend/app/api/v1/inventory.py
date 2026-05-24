import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.repositories.movement import MovementRepository
from app.schemas.movement import MovementCreate, MovementResponse
from app.services.inventory_service import InventoryService

router = APIRouter(prefix="/inventory", tags=["inventory"])


@router.post("/movements", response_model=MovementResponse, status_code=201)
async def create_movement(
    body: MovementCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await InventoryService(db).apply_movement(body, current_user.id)


@router.get("/movements", response_model=list[MovementResponse])
async def list_movements(
    branch_id: uuid.UUID = Query(...),
    product_id: uuid.UUID | None = Query(None),
    limit: int = Query(100, le=500),
    offset: int = Query(0),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    repo = MovementRepository(db)
    if product_id:
        return await repo.list_for_product(product_id, limit=limit)
    return await repo.list_for_branch(branch_id, limit=limit, offset=offset)


@router.get("/movements/{movement_id}", response_model=MovementResponse)
async def get_movement(
    movement_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    from fastapi import HTTPException, status
    repo = MovementRepository(db)
    m = await repo.get(movement_id)
    if not m:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movement not found")
    return m
