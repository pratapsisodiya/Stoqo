import json
import uuid
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.movement import MovementType
from app.models.sync import MutationOperation, MutationStatus, SyncMutation
from app.repositories.alert import AlertRepository
from app.repositories.movement import MovementRepository
from app.repositories.product import ProductRepository
from app.repositories.sync import SyncMutationRepository
from app.schemas.movement import MovementCreate
from app.schemas.sync import MutationPayload, MutationResult, PullResponse, PushResponse
from app.services.conflict_service import ConflictService
from app.services.inventory_service import InventoryService


class SyncService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.mutation_repo = SyncMutationRepository(db)
        self.product_repo = ProductRepository(db)
        self.movement_repo = MovementRepository(db)
        self.alert_repo = AlertRepository(db)
        self.inventory = InventoryService(db)
        self.conflict = ConflictService(db)

    async def push(self, device_id: str, mutations: list[MutationPayload]) -> PushResponse:
        response = PushResponse()

        for m in mutations:
            existing = await self.mutation_repo.get_by_idempotency_key(m.idempotency_key)
            if existing:
                response.accepted.append(
                    MutationResult(mutation_id=m.mutation_id, status=existing.status)
                )
                continue

            mutation = SyncMutation(
                id=m.mutation_id,
                device_id=device_id,
                entity_type=m.entity_type,
                entity_id=m.entity_id,
                operation=m.operation,
                payload_json=json.dumps(m.payload),
                base_version=m.base_version,
                idempotency_key=m.idempotency_key,
                status=MutationStatus.processing,
            )
            self.db.add(mutation)
            await self.db.flush()

            try:
                status, conflict_type = await self._dispatch(mutation, m.payload)
                mutation.status = status
                mutation.processed_at = datetime.now(timezone.utc)
                await self.db.flush()

                result = MutationResult(mutation_id=m.mutation_id, status=status, conflict_type=conflict_type)
                if status == MutationStatus.conflict:
                    response.conflicted.append(result)
                elif status == MutationStatus.failed:
                    response.failed.append(result)
                else:
                    response.accepted.append(result)
            except Exception as exc:
                mutation.status = MutationStatus.failed
                mutation.last_error = str(exc)
                mutation.retry_count += 1
                await self.db.flush()
                response.failed.append(MutationResult(mutation_id=m.mutation_id, status=MutationStatus.failed))

        return response

    async def _dispatch(
        self, mutation: SyncMutation, payload: dict
    ) -> tuple[MutationStatus, str | None]:
        if mutation.entity_type == "inventory_movement":
            try:
                move_data = MovementCreate(
                    product_id=payload["product_id"],
                    branch_id=payload["branch_id"],
                    type=MovementType(payload["type"]),
                    quantity=payload["quantity"],
                    reason=payload.get("reason"),
                    device_id=payload.get("device_id"),
                    mutation_id=mutation.entity_id,
                )
                await self.inventory.apply_movement(move_data, created_by=None)
                return MutationStatus.synced, None
            except Exception as exc:
                return MutationStatus.failed, str(exc)

        if mutation.entity_type == "product":
            return await self.conflict.handle_product_mutation(mutation, payload)

        return MutationStatus.failed, f"unknown_entity_type:{mutation.entity_type}"

    async def pull(self, branch_id: uuid.UUID, cursor: str | None) -> PullResponse:
        from sqlalchemy import select
        from app.models.product import Product
        from app.models.movement import InventoryMovement
        from app.models.alert import Alert

        since = datetime.fromisoformat(cursor) if cursor else datetime.min.replace(tzinfo=timezone.utc)

        products_q = await self.db.execute(
            select(Product).where(Product.branch_id == branch_id, Product.updated_at > since)
        )
        products = products_q.scalars().all()

        moves_q = await self.db.execute(
            select(InventoryMovement).where(
                InventoryMovement.branch_id == branch_id,
                InventoryMovement.created_at > since,
            ).order_by(InventoryMovement.created_at.asc()).limit(500)
        )
        movements = moves_q.scalars().all()

        alerts_q = await self.db.execute(
            select(Alert).where(Alert.branch_id == branch_id, Alert.created_at > since)
        )
        alerts = alerts_q.scalars().all()

        now = datetime.now(timezone.utc)
        return PullResponse(
            products=[self._to_dict(p) for p in products],
            movements=[self._to_dict(m) for m in movements],
            alerts=[self._to_dict(a) for a in alerts],
            deleted_ids=[p.id for p in products if p.deleted_at is not None],
            next_cursor=now.isoformat(),
            synced_at=now,
        )

    @staticmethod
    def _to_dict(obj) -> dict:
        return {c.name: getattr(obj, c.name) for c in obj.__table__.columns}
