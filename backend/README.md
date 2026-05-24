# Stoqo Backend

Offline-first inventory management API — FastAPI + PostgreSQL + Redis.

## Architecture

### Why local-first + movement-ledger?

**Local-first** means the Flutter app writes to a local DB first, UI updates instantly, and mutations queue for sync later. Network failures are invisible to the user. This is the correct model for small shops with unreliable connectivity.

**Movement-ledger** means we never let a client set `current_quantity` directly. Every stock change creates an `InventoryMovement` row with `type`, `quantity`, `quantity_before`, and `quantity_after`. This lets the server safely merge concurrent updates from multiple devices — instead of a last-write-wins quantity overwrite (which loses data), the server replays the movement log and derives a correct total.

### Conflict resolution

| Case | Strategy |
|------|----------|
| Product metadata edited on 2 devices | Latest version wins (safe for names/prices) |
| Quantity changed on 2 devices | Movement ledger merge (never overwrite totals) |
| Admin changes threshold | Server/admin wins |
| Deleted product + pending stock-out | Reject and log conflict |
| Duplicate sync request | Idempotency key de-duplication |
| Transfer receive duplicated | Idempotency key ignore |

### Sync flow

```
Device action → local DB write (instant) → SyncMutation queued
    ↓ (when online)
POST /sync/push → server validates + applies transactionally
    ← accepted / conflicted / failed per mutation
GET /sync/pull?cursor=... → server returns delta since cursor
    ← changed products, movements, alerts, next cursor
```

## Setup

### Prerequisites
- Python 3.12+
- [uv](https://docs.astral.sh/uv/)
- Docker (for postgres + redis)

### Quick start

```bash
# 1. Start dependencies
docker-compose up -d db redis

# 2. Install dependencies
uv sync

# 3. Copy env
cp .env.example .env

# 4. Run migrations
uv run alembic upgrade head

# 5. Seed sample data
uv run python scripts/seed.py

# 6. Start API
uv run uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

### Demo credentials (after seed)
- Admin: `admin@stoqo.com` / `admin1234`
- Staff: `+628001234001` / `staff1234`

## Project structure

```
app/
  api/v1/          — REST routes (auth, products, inventory, purchases,
                     transfers, alerts, sync, websocket)
  core/            — config, security, database, redis, deps
  models/          — SQLAlchemy ORM models
  schemas/         — Pydantic v2 request/response schemas
  repositories/    — DB access layer (generic base + per-entity)
  services/        — Business logic (inventory, sync, conflict, alerts, transfers)
  workers/         — APScheduler jobs (low-stock check every 15m,
                     reconciliation nightly at 02:00)
  main.py          — FastAPI app + scheduler lifecycle
alembic/           — Database migrations
scripts/seed.py    — Demo data (2 branches, 50 products, sample movements)
```

## Key API endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/login` | Get JWT tokens |
| GET | `/api/v1/products?branch_id=` | List products |
| GET | `/api/v1/products/search?branch_id=&q=` | Search by name/SKU/barcode |
| POST | `/api/v1/inventory/movements` | Record stock change |
| POST | `/api/v1/purchases` | Create purchase (auto stock-in) |
| POST | `/api/v1/transfers` | Create transfer |
| PATCH | `/api/v1/transfers/{id}/approve` | Approve + deduct source |
| PATCH | `/api/v1/transfers/{id}/receive` | Receive + add to destination |
| POST | `/api/v1/sync/push` | Push device mutations |
| GET | `/api/v1/sync/pull?branch_id=&cursor=` | Pull remote delta |
| WS | `/ws/inventory/{branch_id}` | Real-time inventory updates |
