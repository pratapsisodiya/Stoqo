from fastapi import APIRouter

from app.api.v1 import alerts, auth, branches, inventory, products, purchases, sync, transfers, websocket

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(branches.router)
api_router.include_router(products.router)
api_router.include_router(inventory.router)
api_router.include_router(purchases.router)
api_router.include_router(transfers.router)
api_router.include_router(alerts.router)
api_router.include_router(sync.router)
api_router.include_router(websocket.router)
