# 📦 Stoqo

[![Flutter](https://img.shields.io/badge/Flutter-3.11.5+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100.0+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7+-DC382D?logo=redis&logoColor=white)](https://redis.io)

Stoqo is a modern, **local-first (offline-first)**, and secure **multi-branch inventory management system** built for small-to-medium retail and wholesale businesses. It is designed to work seamlessly under unstable network conditions by caching operations locally and syncing them in the background using a conflict-free movement ledger.

---

## 🏗️ Architecture & Core Concepts

### 1. Local-First Design
Instead of waiting for API responses before updating the UI, Stoqo's Flutter client writes instantly to a local SQLite database. Mutations are queued as offline tasks and synchronized in the background whenever network connectivity is detected. This guarantees zero latency and 100% offline uptime for staff on the warehouse floor.

### 2. Movement Ledger Merge (Conflict Resolution)
To avoid losing stock changes in multi-device environments, Stoqo does not overwrite the current stock quantity directly. Instead, every operation is stored as a **Stock Movement Ledger entry**. The server resolves concurrent updates transactionally:

```
[Device A (Offline)] -> Sells 5 units (Creates Movement -5)   ┐
                                                               ├─> [Server Ledger Replay] -> Correct Final Stock
[Device B (Offline)] -> Restocks 10 units (Creates Movement +10) ┘
```

#### Conflict Resolution Matrix:
| Mutation Type | Scenario | Resolution Strategy |
|:---|:---|:---|
| **Product Metadata** | Price/name changed on two devices | **Latest version wins** (timestamp-based override) |
| **Stock Levels** | Quantity adjusted on two devices simultaneously | **Movement Ledger Merge** (adds/subtracts delta to/from current pool) |
| **Admin Rules** | Restock thresholds changed on server | **Server/Admin wins** (local overrides are discarded) |
| **Product Deletion** | Deleted on server, but pending sales exist on client | **Conflict flagged** (logged and held for review; sale is recorded against a legacy reference) |
| **Network Retries** | Duplicate sync payloads received by server | **Idempotent verification** via client-generated UUID keys |

---

## 📂 Project Structure

The project is split into two primary components:

* **`/backend`**: The FastAPI application serving REST endpoints, managing database transactions, conflict resolution, background workers, and WebSocket notifications.
* **`/stoqomobile`**: The Flutter application utilizing Riverpod for state management, SQLite for local caching, and custom background services for offline sync.

```
Stoqo/
├── backend/                  # FastAPI + PostgreSQL + Redis
│   ├── app/
│   │   ├── api/v1/           # REST endpoints & WebSockets
│   │   ├── models/           # SQLAlchemy ORM Models
│   │   ├── services/         # Sync, transfers, conflict & alert logic
│   │   └── workers/          # Background cron jobs (low-stock alerts, nightly audits)
│   ├── alembic/              # Database migrations
│   └── scripts/              # Seed data scripts
│
└── stoqomobile/              # Flutter App
    ├── lib/
    │   ├── core/sync/        # Background sync, DB handlers, connectivity
    │   ├── features/         # Modular feature folders (auth, inventory, transfers, alerts, sync)
    │   └── shared/           # Reusable widgets and providers
    └── pubspec.yaml          # Flutter dependencies
```

---

## 🛠️ Technology Stack

### Backend
* **FastAPI**: Asynchronous Python web framework.
* **PostgreSQL**: Relational database for system of record.
* **Redis**: Caching, session store, and WebSocket message broker.
* **SQLAlchemy**: ORM with async support.
* **Alembic**: Database migrations management.
* **APScheduler**: Periodic jobs (low stock checker, reconciliation).

### Mobile App (Flutter)
* **Riverpod**: State management and dependency injection.
* **GoRouter**: Declarative routing.
* **SQLite (sqflite)**: Local-first offline database.
* **Dio**: HTTP networking client with interceptors.
* **Mobile Scanner**: Barcode scanning via native device cameras.
* **Connectivity Plus**: Real-time network detection.

---

## 🚀 Getting Started

### 1. Set Up the Backend

Make sure you have **Docker**, **Python 3.12+**, and [**uv**](https://docs.astral.sh/uv/) installed.

```bash
# Navigate to the backend directory
cd backend

# Start PostgreSQL and Redis containers
docker-compose up -d db redis

# Install dependencies using uv
uv sync

# Create env file
cp .env.example .env

# Run database migrations
uv run alembic upgrade head

# Seed sample data (creates branches, users, and 50+ products)
uv run python scripts/seed.py

# Start the development server
uv run uvicorn app.main:app --reload
```

* **API Documentation**: [http://localhost:8000/docs](http://localhost:8000/docs)
* **Seed Credentials**:
  * **Admin Account**: `admin@stoqo.com` / `admin1234`
  * **Staff Account**: `+628001234001` / `staff1234`

---

### 2. Set Up the Mobile Client

Make sure you have the Flutter SDK configured.

```bash
# Navigate to the mobile directory
cd stoqomobile

# Fetch flutter dependencies
flutter pub get

# Run the Flutter analyzer to verify code health
flutter analyze

# Run the project on a connected device/emulator
flutter run
```

---

## 🔄 Sync Protocol Flow

Every client mutation is pushed transactionally in sequence:

```
   [Local Action] 
         │
         ▼
 ┌───────────────┐
 │ Save Local DB │
 └───────┬───────┘
         │ (instant)
         ▼
 ┌───────────────┐
 │ Queue Sync    │
 └───────┬───────┘
         │
         ├───────────────────► [Offline] (Wait until network is restored)
         │ (when Online)
         ▼
 ┌───────────────┐
 │ POST /sync/push◄──────────► Push payload with idempotency keys
 └───────┬───────┘
         │
         ▼
 ┌───────────────┐
 │ GET /sync/pull◄───────────► Pull remote changes since local cursor
 └───────────────┘
```

---

## 🤝 Key API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/auth/login` | User login (returns JWT token) |
| `GET` | `/api/v1/products` | Paginated product listing |
| `POST` | `/api/v1/inventory/movements` | Log stock updates (in/out/adjust) |
| `POST` | `/api/v1/transfers` | Request product transfer to another branch |
| `PATCH` | `/api/v1/transfers/{id}/approve` | Approve transfer request (deducts origin) |
| `PATCH` | `/api/v1/transfers/{id}/receive` | Confirm receipt of transfer (adds to destination) |
| `POST` | `/api/v1/sync/push` | Submit pending client mutations |
| `GET` | `/api/v1/sync/pull` | Retrieve remote changes since cursor |
| `WS` | `/ws/inventory/{branch_id}` | Real-time WebSocket connection for stock changes |
