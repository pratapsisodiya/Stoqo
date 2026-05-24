import 'package:stoqomobile/core/database/app_database.dart';

/// Lightweight mutation counter kept for audit trail.
/// No network push/pull — WiFi sync is handled by WifiSyncServer/Client.
class SyncEngine {
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

  /// Clear the local mutation log (call after a successful WiFi sync).
  Future<void> clearSynced() async {
    final db = await AppDatabase.instance;
    await db.delete('pending_mutations',
        where: "status='synced'");
  }
}

class SyncResult {
  final int accepted;
  final int conflicted;
  final int failed;
  const SyncResult(
      {required this.accepted, required this.conflicted, required this.failed});
}
