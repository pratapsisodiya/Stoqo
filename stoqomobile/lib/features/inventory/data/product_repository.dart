import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/features/inventory/domain/models/movement_model.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';

class ProductRepository {
  final _uuid = const Uuid();

  // ── Reads ─────────────────────────────────────────────────────────────────

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

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<ProductModel> createProduct({
    required String branchId,
    required String name,
    required String sku,
    String? barcode,
    String? category,
    required String unit,
    required double costPrice,
    required double sellingPrice,
    required int minStockLevel,
    int initialQuantity = 0,
  }) async {
    final db = await AppDatabase.instance;
    final product = ProductModel(
      id: _uuid.v4(),
      branchId: branchId,
      sku: sku.isEmpty ? _autoSku() : sku,
      barcode: barcode?.isEmpty == true ? null : barcode,
      name: name,
      category: category?.isEmpty == true ? null : category,
      unit: unit,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      minStockLevel: minStockLevel,
      currentQuantity: initialQuantity,
      version: 1,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
    await db.insert('products', product.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return product;
  }

  Future<void> updateProduct(ProductModel product) async {
    final db = await AppDatabase.instance;
    await db.update(
      'products',
      {
        ...product.toDb(),
        'version': product.version + 1,
        'updated_at': DateTime.now().toIso8601String(),
        'is_dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(String productId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'products',
      {'deleted_at': DateTime.now().toIso8601String(), 'is_dirty': 1},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ── Stock movements ───────────────────────────────────────────────────────

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
      mutationId: _uuid.v4(),
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

    return movement;
  }

  // ── Movement reads ────────────────────────────────────────────────────────

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
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final db = await AppDatabase.instance;
    final rows = await db.query('inventory_movements',
        where: 'branch_id = ? AND created_at >= ?',
        whereArgs: [branchId, start],
        orderBy: 'created_at DESC');
    return rows.map(MovementModel.fromDb).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _delta(String type, int qty) {
    const positive = {'stock_in', 'transfer_in', 'purchase', 'return'};
    const negative = {'stock_out', 'transfer_out', 'sale'};
    if (positive.contains(type)) return qty;
    if (negative.contains(type)) return -qty;
    return qty;
  }

  String _autoSku() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'SKU-${ts.substring(ts.length - 6)}';
  }
}
