import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/core/sync/connectivity_service.dart';
import 'package:stoqomobile/core/sync/sync_engine.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

class BackgroundSyncService {
  static BackgroundSyncService? _instance;
  static BackgroundSyncService get instance =>
      _instance ??= BackgroundSyncService._();
  BackgroundSyncService._();

  StreamSubscription<bool>? _connectivitySub;
  Timer? _periodicTimer;
  ProviderContainer? _container;
  bool _wasOffline = false;

  void start(ProviderContainer container) {
    _container = container;
    _connectivitySub?.cancel();
    _connectivitySub = ConnectivityService.instance.onlineStream.listen(_onConnectivityChange);
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sync(),
    );
  }

  void stop() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    _connectivitySub = null;
    _periodicTimer = null;
  }

  void _onConnectivityChange(bool online) {
    if (online && _wasOffline) {
      _sync();
    }
    _wasOffline = !online;
  }

  Future<void> _sync() async {
    final container = _container;
    if (container == null) return;
    try {
      container.read(syncNotifierProvider.notifier).syncNow();
    } catch (_) {}
  }
}

final backgroundSyncProvider = Provider<BackgroundSyncService>(
  (_) => BackgroundSyncService.instance,
);
