import json
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conflict import ConflictLog
from app.models.product import Product
from app.models.sync import MutationStatus, SyncMutation
from app.repositories.product import ProductRepository


class ConflictService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.product_repo = ProductRepository(db)

    async def handle_product_mutation(
        self, mutation: SyncMutation, payload: dict[str, Any]
    ) -> tuple[MutationStatus, str | None]:
        product = await self.product_repo.get(mutation.entity_id)

        if mutation.operation == "delete":
            if product and product.deleted_at is None:
                product.deleted_at = datetime.now(timezone.utc)
                product.version += 1
                await self.db.flush()
                return MutationStatus.synced, None
            return MutationStatus.synced, None

        if mutation.operation == "create":
            if product:
                return MutationStatus.synced, None
            new_product = Product(
                id=mutation.entity_id,
                **{k: v for k, v in payload.items() if k not in ("id", "version", "current_quantity")},
                version=1,
            )
            self.db.add(new_product)
            await self.db.flush()
            return MutationStatus.synced, None

        if mutation.operation == "update" and product:
            if product.deleted_at is not None:
                await self._log_conflict(mutation, "deleted_product_update", product.version)
                return MutationStatus.conflict, "deleted_product_update"

            base_version = mutation.base_version or 0
            if product.version > base_version + 1:
                safe_fields = {"name", "category", "unit", "cost_price", "selling_price", "min_stock_level", "notes", "barcode", "sku"}
                for field in safe_fields:
                    if field in payload:
                        setattr(product, field, payload[field])
                product.version += 1
                product.updated_at = datetime.now(timezone.utc)
                await self._log_conflict(mutation, "metadata_merge_latest_wins", product.version)
                await self.db.flush()
                return MutationStatus.synced, "metadata_merge_latest_wins"

            for field, val in payload.items():
                if field not in ("id", "version", "current_quantity", "branch_id"):
                    setattr(product, field, val)
            product.version += 1
            product.updated_at = datetime.now(timezone.utc)
            await self.db.flush()
            return MutationStatus.synced, None

        return MutationStatus.failed, "entity_not_found"

    async def _log_conflict(self, mutation: SyncMutation, conflict_type: str, server_version: int) -> None:
        log = ConflictLog(
            entity_type=mutation.entity_type,
            entity_id=mutation.entity_id,
            local_version=mutation.base_version,
            server_version=server_version,
            conflict_type=conflict_type,
            resolution_strategy="server_merge",
            mutation_id=mutation.id,
            conflict_payload=mutation.payload_json,
        )
        self.db.add(log)
