# 📱 Stoqo Mobile

The official mobile client for Stoqo, a local-first multi-branch inventory management system. Built with Flutter, this application is optimized for warehouse and store operations under unreliable network conditions.

---

## ✨ Features

* **Offline-First & Local Caching**: Instant UI feedback. Reads and writes hit a local SQLite database before syncing.
* **Sync Center**: Real-time background synchronization using Riverpod and SQLite-based mutation queueing. Includes detailed conflict visibility.
* **Barcode Scanning**: Instant product search and stock logging via native camera integration using `mobile_scanner`.
* **Inter-Branch Stock Transfers**: Full workflow to request, approve, and receive stock transfers across physical locations.
* **Real-time Alerts**: Automated local notifications for low-stock products.
* **Branch Picker**: Smooth switching between authorized branch locations on login.

---

## 🛠️ Tech Stack & Libraries

* **Framework**: Flutter (Dart)
* **State Management**: [Riverpod](https://pub.dev/packages/flutter_riverpod) (Notifier, StateProvider, FutureProvider)
* **Navigation**: [GoRouter](https://pub.dev/packages/go_router) (Declarative routing setup)
* **Database**: [sqflite](https://pub.dev/packages/sqflite) (Local SQLite client)
* **API / HTTP Client**: [Dio](https://pub.dev/packages/dio) (Configured with custom interceptors for auth headers)
* **Secure Storage**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (For storing user credentials and auth tokens safely)
* **Connectivity Tracking**: [connectivity_plus](https://pub.dev/packages/connectivity_plus) (Detects cellular/Wi-Fi states)
* **Local Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) (Alert triggers for inventory thresholds)

---

## 📂 Directory Layout

```
lib/
├── app.dart                   # Material App & Router configuration
├── main.dart                  # App bootstrap, Riverpod container initialization
├── core/                      # Global singletons and configurations
│   ├── database/              # SQLite DB initialization & helper methods
│   ├── network/               # Dio client and API URL configuration
│   └── sync/                  # Connectivity monitors, background sync scheduler
│
├── features/                  # Modular feature-first folders
│   ├── auth/                  # Login, Branch Selection
│   ├── inventory/             # Stock dashboard, item detail view, stock logging
│   ├── transfers/             # Stock request, approval, and receipt screens
│   ├── sync_center/           # Sync logs, mutation queues, conflict viewer
│   ├── alerts/                # Low stock warnings list
│   └── barcode/               # Camera scanner overlay
│
└── shared/                    # Reusable global items
    ├── providers/             # Global session and device info provider
    └── widgets/               # Custom buttons, badges, load animations
```

---

## 🚀 Setup & Execution

### Prerequisites

* Flutter SDK (`^3.11.5`)
* Dart SDK (`^3.11.5`)
* Android Studio / Xcode (for simulators/emulators)

### Quick Start

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Verify code quality**:
   ```bash
   flutter analyze
   ```

3. **Run on a device / emulator**:
   ```bash
   # Launch default active emulator
   flutter run
   
   # Or run on a specific device
   flutter run -d <device_id>
   ```

---

## 🔄 How the Offline Sync Engine Works

1. **Write Local**: All operations (logging inventory, creating transfers, etc.) are executed instantly in the local SQLite database.
2. **Enqueue Mutation**: A corresponding mutation payload is saved to the `sync_mutations` table in SQLite.
3. **Connectivity Hook**: `ConnectivityService` monitors network status. The moment the connection transitions to online, a background sync service initiates.
4. **Push & Pull**:
   * The app pushes all pending mutations to `/api/v1/sync/push`.
   * Upon successful push, it clears the local queue and calls `/api/v1/sync/pull?cursor=...` to update local databases with remote modifications made by other branches/admins.
