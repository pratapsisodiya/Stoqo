import asyncio
import logging

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.models.branch import Branch
from app.services.alert_service import AlertService

logger = logging.getLogger(__name__)


async def run_low_stock_check() -> None:
    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(select(Branch))
            branches = result.scalars().all()
            service = AlertService(db)
            for branch in branches:
                alerts = await service.check_and_create_low_stock_alerts(branch.id)
                if alerts:
                    logger.info("Created %d low-stock alerts for branch %s", len(alerts), branch.code)
            await db.commit()
        except Exception:
            logger.exception("Low-stock check failed")
            await db.rollback()
