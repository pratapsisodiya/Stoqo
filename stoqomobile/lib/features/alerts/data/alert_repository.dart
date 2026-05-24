import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/network/api_client.dart';
import 'package:stoqomobile/features/alerts/domain/models/alert_model.dart';

class AlertRepository {
  Future<List<AlertModel>> getAlerts(String branchId,
      {bool unreadOnly = false}) async {
    final db = await AppDatabase.instance;
    String where = 'branch_id = ?';
    final args = <dynamic>[branchId];
    if (unreadOnly) {
      where += ' AND is_read = 0';
    }
    final rows = await db.query('alerts',
        where: where, whereArgs: args, orderBy: 'created_at DESC');
    return rows.map(AlertModel.fromDb).toList();
  }

  Future<int> unreadCount(String branchId) async {
    final db = await AppDatabase.instance;
    final r = await db.rawQuery(
        'SELECT COUNT(*) as c FROM alerts WHERE branch_id = ? AND is_read = 0',
        [branchId]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> markRead(String alertId) async {
    final db = await AppDatabase.instance;
    await db.update('alerts', {'is_read': 1},
        where: 'id = ?', whereArgs: [alertId]);
    try {
      await ApiClient.instance.dio.patch('/alerts/$alertId/read');
    } catch (_) {}
  }

  Future<void> markAllRead(String branchId) async {
    final db = await AppDatabase.instance;
    await db.update('alerts', {'is_read': 1},
        where: 'branch_id = ?', whereArgs: [branchId]);
  }
}
