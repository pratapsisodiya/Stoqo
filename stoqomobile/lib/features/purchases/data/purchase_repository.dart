import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/features/purchases/domain/models/purchase_model.dart';

class PurchaseRepository {
  Future<List<PurchaseModel>> getPurchases(String branchId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('purchases',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        orderBy: 'created_at DESC',
        limit: 100);
    final purchases = <PurchaseModel>[];
    for (final row in rows) {
      final items = await db.query('purchase_items',
          where: 'purchase_id = ?', whereArgs: [row['id']]);
      purchases.add(PurchaseModel.fromDb(row,
          items: items.map(PurchaseItemModel.fromDb).toList()));
    }
    return purchases;
  }

  Future<PurchaseModel?> createPurchase({
    required String branchId,
    required String createdBy,
    String? supplierName,
    String? invoiceNumber,
    double totalAmount = 0,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await AppDatabase.instance;
    final id = 'po_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    await db.insert('purchases', {
      'id': id,
      'branch_id': branchId,
      'supplier_name': supplierName,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount,
      'purchase_date': now,
      'created_by': createdBy,
      'created_at': now,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final item in items) {
      await db.insert('purchase_items', {
        'id': 'pi_${DateTime.now().microsecondsSinceEpoch}_${item['product_id']}',
        'purchase_id': id,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_cost': item['unit_cost'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return getPurchases(branchId)
        .then((list) => list.where((p) => p.id == id).firstOrNull);
  }
}
