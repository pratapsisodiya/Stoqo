import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.redis import close_redis

logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="Stoqo Inventory API",
    version="1.0.0",
    description="Offline-first inventory management backend",
    docs_url="/docs" if settings.DEBUG else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)

scheduler = AsyncIOScheduler()


@app.on_event("startup")
async def startup() -> None:
    from app.workers.low_stock_worker import run_low_stock_check
    from app.workers.reconciliation_worker import reconcile_quantities

    scheduler.add_job(run_low_stock_check, "interval", minutes=15, id="low_stock")
    scheduler.add_job(reconcile_quantities, "cron", hour=2, minute=0, id="reconcile")
    scheduler.start()


@app.on_event("shutdown")
async def shutdown() -> None:
    scheduler.shutdown(wait=False)
    await close_redis()


@app.get("/health")
async def health():
    return {"status": "ok", "version": app.version}
