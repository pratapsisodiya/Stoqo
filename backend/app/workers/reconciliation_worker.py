import logging

from sqlalchemy import func, select, text

from app.core.database import AsyncSessionLocal
from app.models.movement import InventoryMovement, MovementType
from app.models.product import Product

logger = logging.getLogger(__name__)

_POSITIVE = (MovementType.stock_in, MovementType.transfer_in, MovementType.purchase, MovementType.return_)
_NEGATIVE = (MovementType.stock_out, MovementType.transfer_out, MovementType.sale)


async def reconcile_quantities() -> None:
    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(select(Product).where(Product.deleted_at.is_(None)))
            products = result.scalars().all()

            for product in products:
                ledger = await db.execute(
                    select(InventoryMovement).where(InventoryMovement.product_id == product.id)
                )
                movements = ledger.scalars().all()

                computed = 0
                for m in movements:
                    if m.type in _POSITIVE:
                        computed += m.quantity
                    elif m.type in _NEGATIVE:
                        computed -= m.quantity
                    else:
                        computed += m.quantity  # adjustment

                if computed != product.current_quantity:
                    logger.warning(
                        "Quantity drift on product %s: stored=%d ledger=%d — correcting",
                        product.id,
                        product.current_quantity,
                        computed,
                    )
                    product.current_quantity = computed
                    product.version += 1

            await db.commit()
            logger.info("Reconciliation complete for %d products", len(products))
        except Exception:
            logger.exception("Reconciliation failed")
            await db.rollback()
