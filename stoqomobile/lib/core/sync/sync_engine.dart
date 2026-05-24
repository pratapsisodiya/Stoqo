import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/network/api_client.dart';

enum MutationStatus { pending, syncing, synced, failed, conflict }

class PendingMutation {
  final String id;
  final String mutationId;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final int? baseVersion;
  MutationStatus status;
  int retryCount;
  String? lastError;
  final DateTime createdAt;

  PendingMutation({
    required this.id,
    required this.mutationId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.baseVersion,
    this.status = MutationStatus.pending,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
  });

  Map<String, dynamic> toDb() => {
        'id': id,
        'mutation_id': mutationId,
        'idempotency_key': idempotencyKey,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload': jsonEncode(payload),
        'base_version': baseVersion,
        'status': status.name,
        'retry_count': retryCount,
        'last_error': lastError,
        'created_at': createdAt.toIso8601String(),
      };
}

class SyncEngine {
  final Dio _dio = ApiClient.instance.dio;
  bool _syncing = false;

  Future<void> enqueue(PendingMutation mutation) async {
    final db = await AppDatabase.instance;
    await db.insert(
      'pending_mutations',
      mutation.toDb(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> pendingCount() async {
    final db = await AppDatabase.instance;
    final r = await db.rawQuery(
        "SELECT COUNT(*) as c FROM pending_mutations WHERE status='pending' OR status='failed'");
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> pendingMutations() async {
    final db = await AppDatabase.instance;
    return db.query(
      'pending_mutations',
      where: "status='pending' OR status='failed'",
      orderBy: 'created_at ASC',
    );
  }

  Future<SyncResult> pushAll(String deviceId) async {
    if (_syncing) return SyncResult(accepted: 0, conflicted: 0, failed: 0);
    _syncing = true;
    int accepted = 0, conflicted = 0, failed = 0;

    try {
      final rows = await pendingMutations();
      if (rows.isEmpty) return SyncResult(accepted: 0, conflicted: 0, failed: 0);

      final mutations = rows.map((r) => {
            'mutation_id': r['mutation_id'],
            'idempotency_key': r['idempotency_key'],
            'entity_type': r['entity_type'],
            'entity_id': r['entity_id'],
            'operation': r['operation'],
            'base_version': r['base_version'],
            'payload': jsonDecode(r['payload'] as String),
          }).toList();

      final response = await _dio.post('/sync/push', data: {
        'device_id': deviceId,
        'mutations': mutations,
      });

      final body = response.data as Map<String, dynamic>;
      final db = await AppDatabase.instance;

      for (final result in (body['accepted'] as List? ?? [])) {
        await db.update(
          'pending_mutations',
          {'status': 'synced'},
          where: 'mutation_id = ?',
          whereArgs: [result['mutation_id']],
        );
        accepted++;
      }

      for (final result in (body['conflicted'] as List? ?? [])) {
        await db.update(
          'pending_mutations',
          {'status': 'conflict', 'last_error': result['conflict_type']},
          where: 'mutation_id = ?',
          whereArgs: [result['mutation_id']],
        );
        conflicted++;
      }

      for (final result in (body['failed'] as List? ?? [])) {
        await db.rawUpdate(
          "UPDATE pending_mutations SET status='failed', retry_count=retry_count+1 WHERE mutation_id=?",
          [result['mutation_id']],
        );
        failed++;
      }
    } catch (_) {
      // network error — mutations stay pending
    } finally {
      _syncing = false;
    }

    return SyncResult(accepted: accepted, conflicted: conflicted, failed: failed);
  }

  Future<void> pullDelta(String branchId, String? cursor) async {
    try {
      final params = <String, dynamic>{'branch_id': branchId};
      if (cursor != null) params['cursor'] = cursor;

      final response = await _dio.get('/sync/pull', queryParameters: params);
      final body = response.data as Map<String, dynamic>;
      final db = await AppDatabase.instance;

      for (final p in (body['products'] as List? ?? [])) {
        await db.insert('products', _normalizeProduct(p),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final a in (body['alerts'] as List? ?? [])) {
        await db.insert('alerts', _normalizeAlert(a),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final nextCursor = body['next_cursor'] as String?;
      if (nextCursor != null) {
        await db.update(
          'branches',
          {'sync_cursor': nextCursor, 'last_synced_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [branchId],
        );
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

class SyncResult {
  final int accepted;
  final int conflicted;
  final int failed;
  SyncResult({required this.accepted, required this.conflicted, required this.failed});
}
