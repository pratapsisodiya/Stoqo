import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/sync/sync_engine.dart';
import 'package:stoqomobile/features/inventory/domain/models/movement_model.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';

class ProductRepository {
  final _uuid = const Uuid();
  final _syncEngine = SyncEngine();

  // ── Reads (local-first) ────────────────────────────────────────────────────

  Future<List<ProductModel>> getProducts(String branchId,
      {String? query, String? category, bool lowStockOnly = false}) async {
    final db = await AppDatabase.instance;
    String where = 'branch_id = ? AND deleted_at IS NULL';
    final args = <dynamic>[branchId];

    if (query != null && query.isNotEmpty) {
      where += ' AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)';
      final pattern = '%$query%';
      args.addAll([pattern, pattern, pattern]);
    }
    if (category != null) {
      where += ' AND category = ?';
      args.add(category);
    }
    if (lowStockOnly) {
      where += ' AND current_quantity <= min_stock_level';
    }
    final rows = await db.query('products',
        where: where, whereArgs: args, orderBy: 'name ASC');
    return rows.map(ProductModel.fromDb).toList();
  }

  Future<ProductModel?> getProduct(String id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ProductModel.fromDb(rows.first);
  }

  Future<ProductModel?> getByBarcode(String branchId, String barcode) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('products',
        where: 'branch_id = ? AND barcode = ? AND deleted_at IS NULL',
        whereArgs: [branchId, barcode]);
    if (rows.isEmpty) return null;
    return ProductModel.fromDb(rows.first);
  }

  Future<int> countProducts(String branchId) async {
    final db = await AppDatabase.instance;
    final r = await db.rawQuery(
        'SELECT COUNT(*) as c FROM products WHERE branch_id = ? AND deleted_at IS NULL',
        [branchId]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> countLowStock(String branchId) async {
    final db = await AppDatabase.instance;
    final r = await db.rawQuery(
        'SELECT COUNT(*) as c FROM products WHERE branch_id = ? AND deleted_at IS NULL AND current_quantity <= min_stock_level AND min_stock_level > 0',
        [branchId]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> countOutOfStock(String branchId) async {
    final db = await AppDatabase.instance;
    final r = await db.rawQuery(
        'SELECT COUNT(*) as c FROM products WHERE branch_id = ? AND deleted_at IS NULL AND current_quantity <= 0',
        [branchId]);
    return (r.first['c'] as int?) ?? 0;
  }

  // ── Writes (local-first → queue sync) ─────────────────────────────────────

  Future<MovementModel> applyMovement({
    required String branchId,
    required ProductModel product,
    required String type,
    required int quantity,
    required String deviceId,
    required String userId,
    String? reason,
  }) async {
    final db = await AppDatabase.instance;
    final mutationId = _uuid.v4();
    final movementId = _uuid.v4();

    final delta = _delta(type, quantity);
    final qBefore = product.currentQuantity;
    final qAfter = qBefore + delta;

    final movement = MovementModel(
      id: movementId,
      productId: product.id,
      branchId: branchId,
      type: type,
      quantity: quantity,
      quantityBefore: qBefore,
      quantityAfter: qAfter,
      reason: reason,
      createdAt: DateTime.now(),
      deviceId: deviceId,
      mutationId: mutationId,
      createdBy: userId,
    );

    await db.transaction((txn) async {
      await txn.insert('inventory_movements', movement.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update(
        'products',
        {
          'current_quantity': qAfter,
          'version': product.version + 1,
          'updated_at': DateTime.now().toIso8601String(),
          'is_dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [product.id],
      );
    });

    // Enqueue for background sync — idempotent (safe to call offline)
    await _syncEngine.enqueue(PendingMutation(
      id: _uuid.v4(),
      mutationId: mutationId,
      idempotencyKey: mutationId,
      entityType: 'inventory_movement',
      entityId: movementId,
      operation: 'create',
      payload: {
        'product_id': product.id,
        'branch_id': branchId,
        'type': type,
        'quantity': quantity,
        'reason': reason,
        'device_id': deviceId,
      },
      createdAt: DateTime.now(),
    ));

    return movement;
  }

  // ── Movement reads ─────────────────────────────────────────────────────────

  Future<List<MovementModel>> getMovements(String branchId,
      {String? productId, int limit = 50}) async {
    final db = await AppDatabase.instance;
    String where = 'branch_id = ?';
    final args = <dynamic>[branchId];
    if (productId != null) {
      where += ' AND product_id = ?';
      args.add(productId);
    }
    final rows = await db.query('inventory_movements',
        where: where,
        whereArgs: args,
        orderBy: 'created_at DESC',
        limit: limit);
    return rows.map(MovementModel.fromDb).toList();
  }

  Future<List<MovementModel>> getTodayMovements(String branchId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final db = await AppDatabase.instance;
    final rows = await db.query('inventory_movements',
        where: 'branch_id = ? AND created_at >= ?',
        whereArgs: [branchId, start],
        orderBy: 'created_at DESC');
    return rows.map(MovementModel.fromDb).toList();
  }

  int _delta(String type, int qty) {
    const positive = {'stock_in', 'transfer_in', 'purchase', 'return'};
    const negative = {'stock_out', 'transfer_out', 'sale'};
    if (positive.contains(type)) return qty;
    if (negative.contains(type)) return -qty;
    return qty; // adjustment
  }
}
