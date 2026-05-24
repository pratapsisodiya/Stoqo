import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/network/api_client.dart';
import 'package:stoqomobile/features/transfers/domain/models/transfer_model.dart';

class TransferRepository {
  final _uuid = const Uuid();

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

  Future<void> syncFromServer(String branchId) async {
    try {
      final response = await ApiClient.instance.dio
          .get('/transfers', queryParameters: {'branch_id': branchId});
      final db = await AppDatabase.instance;
      for (final t in (response.data as List? ?? [])) {
        final transfer = t as Map<String, dynamic>;
        await db.insert('transfers', {
          'id': transfer['id'],
          'from_branch_id': transfer['from_branch_id'],
          'to_branch_id': transfer['to_branch_id'],
          'status': transfer['status'] ?? 'pending',
          'notes': transfer['notes'],
          'created_by': transfer['created_by'],
          'approved_by': transfer['approved_by'],
          'created_at': transfer['created_at'],
          'approved_at': transfer['approved_at'],
          'received_at': transfer['received_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final item in (transfer['items'] as List? ?? [])) {
          final i = item as Map<String, dynamic>;
          await db.insert('transfer_items', {
            'id': i['id'],
            'transfer_id': transfer['id'],
            'product_id': i['product_id'],
            'quantity': i['quantity'],
            'received_quantity': i['received_quantity'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (_) {}
  }

  Future<TransferModel?> createTransfer({
    required String fromBranchId,
    required String toBranchId,
    required String createdBy,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/transfers', data: {
        'from_branch_id': fromBranchId,
        'to_branch_id': toBranchId,
        'notes': notes,
        'items': items,
      });
      final data = response.data as Map<String, dynamic>;
      final db = await AppDatabase.instance;
      await db.insert('transfers', {
        'id': data['id'],
        'from_branch_id': data['from_branch_id'],
        'to_branch_id': data['to_branch_id'],
        'status': data['status'],
        'notes': data['notes'],
        'created_by': data['created_by'],
        'created_at': data['created_at'],
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return getTransfers(fromBranchId).then((list) =>
          list.where((t) => t.id == data['id']).firstOrNull);
    } catch (_) {
      return null;
    }
  }
}
