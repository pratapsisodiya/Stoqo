import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/network/api_client.dart';
import 'package:stoqomobile/core/sync/sync_engine.dart';

/// Pulls the full dataset for a branch on first login or forced refresh.
/// After this runs, all reads are from local SQLite — no network needed.
class InitialSyncService {
  final SyncEngine _engine;
  InitialSyncService(this._engine);

  Future<void> syncBranch(String branchId, {String? cursor}) async {
    await _pullProducts(branchId);
    await _pullAlerts(branchId);
    await _pullTransfers(branchId);
    await _pullPurchases(branchId);
    await _engine.pullDelta(branchId, cursor);
  }

  Future<void> _pullProducts(String branchId) async {
    try {
      final response = await ApiClient.instance.dio.get(
        '/products',
        queryParameters: {'branch_id': branchId},
      );
      final db = await AppDatabase.instance;
      final batch = db.batch();
      for (final p in (response.data as List? ?? [])) {
        batch.insert('products', _normalizeProduct(p as Map<String, dynamic>),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<void> _pullAlerts(String branchId) async {
    try {
      final response = await ApiClient.instance.dio.get(
        '/alerts',
        queryParameters: {'branch_id': branchId},
      );
      final db = await AppDatabase.instance;
      final batch = db.batch();
      for (final a in (response.data as List? ?? [])) {
        batch.insert('alerts', _normalizeAlert(a as Map<String, dynamic>),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<void> _pullTransfers(String branchId) async {
    try {
      final response = await ApiClient.instance.dio.get(
        '/transfers',
        queryParameters: {'branch_id': branchId},
      );
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

  Future<void> _pullPurchases(String branchId) async {
    try {
      final response = await ApiClient.instance.dio.get(
        '/purchases',
        queryParameters: {'branch_id': branchId},
      );
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

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> p) => {
        'id': p['id'],
        'branch_id': p['branch_id'],
        'sku': p['sku'] ?? '',
        'barcode': p['barcode'],
        'name': p['name'] ?? '',
        'category': p['category'],
        'unit': p['unit'] ?? 'pcs',
        'cost_price': (p['cost_price'] as num?)?.toDouble() ?? 0,
        'selling_price': (p['selling_price'] as num?)?.toDouble() ?? 0,
        'min_stock_level': p['min_stock_level'] ?? 0,
        'current_quantity': p['current_quantity'] ?? 0,
        'version': p['version'] ?? 1,
        'updated_at': p['updated_at'],
        'deleted_at': p['deleted_at'],
        'is_dirty': 0,
      };

  Map<String, dynamic> _normalizeAlert(Map<String, dynamic> a) => {
        'id': a['id'],
        'branch_id': a['branch_id'],
        'product_id': a['product_id'],
        'type': a['type'],
        'message': a['message'] ?? '',
        'is_read': (a['is_read'] == true) ? 1 : 0,
        'created_at': a['created_at'],
      };
}
