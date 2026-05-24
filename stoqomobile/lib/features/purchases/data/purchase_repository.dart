import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/network/api_client.dart';
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

  Future<void> syncFromServer(String branchId) async {
    try {
      final response = await ApiClient.instance.dio
          .get('/purchases', queryParameters: {'branch_id': branchId});
      final db = await AppDatabase.instance;
      for (final p in (response.data as List? ?? [])) {
        final purchase = p as Map<String, dynamic>;
        await db.insert('purchases', {
          'id': purchase['id'],
          'branch_id': purchase['branch_id'],
          'supplier_name': purchase['supplier_name'],
          'invoice_number': purchase['invoice_number'],
          'total_amount': purchase['total_amount'],
          'purchase_date': purchase['purchase_date'],
          'created_by': purchase['created_by'],
          'created_at': purchase['created_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final item in (purchase['items'] as List? ?? [])) {
          final i = item as Map<String, dynamic>;
          await db.insert('purchase_items', {
            'id': i['id'],
            'purchase_id': purchase['id'],
            'product_id': i['product_id'],
            'quantity': i['quantity'],
            'unit_cost': i['unit_cost'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (_) {}
  }
}
