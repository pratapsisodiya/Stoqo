import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<void> showLowStockAlert({
    required String productName,
    required int quantity,
    required int minLevel,
  }) async {
    await _ensureInit();
    await _plugin.show(
      productName.hashCode,
      'Low Stock Alert',
      '$productName: $quantity remaining (min $minLevel)',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'low_stock',
          'Low Stock Alerts',
          channelDescription: 'Alerts when products are running low',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showSyncComplete(int synced, int failed) async {
    if (synced == 0 && failed == 0) return;
    await _ensureInit();
    await _plugin.show(
      9999,
      'Sync Complete',
      '$synced synced${failed > 0 ? ', $failed failed' : ''}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sync_status',
          'Sync Status',
          channelDescription: 'Background sync notifications',
          importance: Importance.low,
          priority: Priority.low,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }
}
