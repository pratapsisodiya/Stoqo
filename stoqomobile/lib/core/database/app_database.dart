import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/config/app_config.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), AppConfig.dbName);
    return openDatabase(path, version: AppConfig.dbVersion, onCreate: _create);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE branches (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        address TEXT,
        sync_cursor TEXT,
        last_synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        branch_id TEXT NOT NULL,
        sku TEXT NOT NULL,
        barcode TEXT,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT DEFAULT 'pcs',
        cost_price REAL DEFAULT 0,
        selling_price REAL DEFAULT 0,
        min_stock_level INTEGER DEFAULT 0,
        current_quantity INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        updated_at TEXT,
        deleted_at TEXT,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_products_branch ON products(branch_id);
    ''');

    await db.execute('''
      CREATE TABLE inventory_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        branch_id TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        quantity_before INTEGER DEFAULT 0,
        quantity_after INTEGER DEFAULT 0,
        reason TEXT,
        reference_type TEXT,
        reference_id TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        device_id TEXT,
        mutation_id TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        branch_id TEXT NOT NULL,
        supplier_name TEXT,
        invoice_number TEXT,
        total_amount REAL DEFAULT 0,
        purchase_date TEXT NOT NULL,
        created_by TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_cost REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        from_branch_id TEXT NOT NULL,
        to_branch_id TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        created_by TEXT,
        approved_by TEXT,
        created_at TEXT NOT NULL,
        approved_at TEXT,
        received_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transfer_items (
        id TEXT PRIMARY KEY,
        transfer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        received_quantity INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE alerts (
        id TEXT PRIMARY KEY,
        branch_id TEXT NOT NULL,
        product_id TEXT,
        type TEXT NOT NULL,
        message TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_mutations (
        id TEXT PRIMARY KEY,
        mutation_id TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        base_version INTEGER,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE conflict_logs (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        conflict_type TEXT NOT NULL,
        resolution_strategy TEXT,
        local_payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
