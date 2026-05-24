import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alert import Alert, AlertType
from app.repositories.alert import AlertRepository
from app.repositories.product import ProductRepository


class AlertService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.product_repo = ProductRepository(db)
        self.alert_repo = AlertRepository(db)

    async def check_and_create_low_stock_alerts(self, branch_id: uuid.UUID) -> list[Alert]:
        low_stock = await self.product_repo.list_low_stock(branch_id)
        created: list[Alert] = []

        for product in low_stock:
            alert_type = AlertType.out_of_stock if product.current_quantity <= 0 else AlertType.low_stock
            already_exists = await self.alert_repo.exists_unread(branch_id, product.id, alert_type)
            if not already_exists:
                alert = Alert(
                    branch_id=branch_id,
                    product_id=product.id,
                    type=alert_type,
                    message=(
                        f"'{product.name}' is out of stock."
                        if product.current_quantity <= 0
                        else f"'{product.name}' is low on stock: {product.current_quantity} left (min {product.min_stock_level})."
                    ),
                )
                self.db.add(alert)
                created.append(alert)

        await self.db.flush()
        return created
