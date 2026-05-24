from sqlalchemy import select

from app.models.sync import MutationStatus, SyncMutation
from app.repositories.base import BaseRepository


class SyncMutationRepository(BaseRepository[SyncMutation]):
    model = SyncMutation

    async def get_by_idempotency_key(self, key: str) -> SyncMutation | None:
        result = await self.db.execute(
            select(SyncMutation).where(SyncMutation.idempotency_key == key)
        )
        return result.scalar_one_or_none()

    async def list_pending(self, device_id: str) -> list[SyncMutation]:
        result = await self.db.execute(
            select(SyncMutation)
            .where(SyncMutation.device_id == device_id, SyncMutation.status == MutationStatus.pending)
            .order_by(SyncMutation.created_at.asc())
        )
        return list(result.scalars().all())
