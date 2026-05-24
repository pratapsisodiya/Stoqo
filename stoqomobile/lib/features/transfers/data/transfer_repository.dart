import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/features/transfers/domain/models/transfer_model.dart';

class TransferRepository {
  Future<List<TransferModel>> getTransfers(String branchId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('transfers',
        where: 'from_branch_id = ? OR to_branch_id = ?',
        whereArgs: [branchId, branchId],
        orderBy: 'created_at DESC');
    final transfers = <TransferModel>[];
    for (final row in rows) {
      final items = await db.query('transfer_items',
          where: 'transfer_id = ?', whereArgs: [row['id']]);
      transfers.add(TransferModel.fromDb(row,
          items: items.map(TransferItemModel.fromDb).toList()));
    }
    return transfers;
  }

  Future<TransferModel?> createTransfer({
    required String fromBranchId,
    required String toBranchId,
    required String createdBy,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await AppDatabase.instance;
    final id = 'tr_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    await db.insert('transfers', {
      'id': id,
      'from_branch_id': fromBranchId,
      'to_branch_id': toBranchId,
      'status': 'pending',
      'notes': notes,
      'created_by': createdBy,
      'created_at': now,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final item in items) {
      await db.insert('transfer_items', {
        'id': 'ti_${DateTime.now().microsecondsSinceEpoch}_${item['product_id']}',
        'transfer_id': id,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'received_quantity': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final list = await getTransfers(fromBranchId);
    return list.where((t) => t.id == id).firstOrNull;
  }
}
