import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.movement import MovementType
from app.models.purchase import Purchase, PurchaseItem
from app.models.user import User
from app.schemas.movement import MovementCreate
from app.schemas.purchase import PurchaseCreate, PurchaseResponse
from app.services.inventory_service import InventoryService

router = APIRouter(prefix="/purchases", tags=["purchases"])


@router.post("", response_model=PurchaseResponse, status_code=201)
async def create_purchase(
    body: PurchaseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    inventory = InventoryService(db)
    purchase = Purchase(
        branch_id=body.branch_id,
        supplier_name=body.supplier_name,
        invoice_number=body.invoice_number,
        total_amount=body.total_amount,
        purchase_date=body.purchase_date,
        created_by=current_user.id,
    )
    db.add(purchase)
    await db.flush()

    for item_data in body.items:
        item = PurchaseItem(
            purchase_id=purchase.id,
            product_id=item_data.product_id,
            quantity=item_data.quantity,
            unit_cost=item_data.unit_cost,
        )
        db.add(item)
        await inventory.apply_movement(
            MovementCreate(
                product_id=item_data.product_id,
                branch_id=body.branch_id,
                type=MovementType.purchase,
                quantity=item_data.quantity,
                reference_type="purchase",
                reference_id=purchase.id,
            ),
            created_by=current_user.id,
        )

    await db.flush()
    result = await db.execute(
        select(Purchase).where(Purchase.id == purchase.id).options(selectinload(Purchase.items))
    )
    return result.scalar_one()


@router.get("", response_model=list[PurchaseResponse])
async def list_purchases(
    branch_id: uuid.UUID = Query(...),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Purchase)
        .where(Purchase.branch_id == branch_id)
        .options(selectinload(Purchase.items))
        .order_by(Purchase.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


@router.get("/{purchase_id}", response_model=PurchaseResponse)
async def get_purchase(
    purchase_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Purchase).where(Purchase.id == purchase_id).options(selectinload(Purchase.items))
    )
    purchase = result.scalar_one_or_none()
    if not purchase:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Purchase not found")
    return purchase
