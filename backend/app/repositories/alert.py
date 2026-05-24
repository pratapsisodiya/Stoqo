import uuid

from sqlalchemy import select

from app.models.alert import Alert, AlertType
from app.repositories.base import BaseRepository


class AlertRepository(BaseRepository[Alert]):
    model = Alert

    async def list_for_branch(self, branch_id: uuid.UUID, unread_only: bool = False) -> list[Alert]:
        q = select(Alert).where(Alert.branch_id == branch_id)
        if unread_only:
            q = q.where(Alert.is_read.is_(False))
        q = q.order_by(Alert.created_at.desc())
        result = await self.db.execute(q)
        return list(result.scalars().all())

    async def exists_unread(self, branch_id: uuid.UUID, product_id: uuid.UUID, alert_type: AlertType) -> bool:
        result = await self.db.execute(
            select(Alert).where(
                Alert.branch_id == branch_id,
                Alert.product_id == product_id,
                Alert.type == alert_type,
                Alert.is_read.is_(False),
            )
        )
        return result.scalar_one_or_none() is not None
