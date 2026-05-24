import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background sync is no longer needed for server push/pull.
/// WiFi sync is user-triggered from the WiFi Sync screen.
/// This class is kept as a stub for future use.
class BackgroundSyncService {
  static BackgroundSyncService? _instance;
  static BackgroundSyncService get instance =>
      _instance ??= BackgroundSyncService._();
  BackgroundSyncService._();

  void start(ProviderContainer container) {}
  void stop() {}
}

final backgroundSyncProvider = Provider<BackgroundSyncService>(
  (_) => BackgroundSyncService.instance,
);
