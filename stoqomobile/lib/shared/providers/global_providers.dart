import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:stoqomobile/core/sync/connectivity_service.dart';
import 'package:stoqomobile/core/sync/sync_engine.dart';
import 'package:stoqomobile/features/auth/data/auth_repository.dart';
import 'package:stoqomobile/features/auth/domain/models/branch_model.dart';
import 'package:stoqomobile/features/auth/domain/models/user_model.dart';
import 'package:stoqomobile/features/inventory/data/product_repository.dart';
import 'package:stoqomobile/features/alerts/data/alert_repository.dart';

// Repositories
final authRepoProvider = Provider<AuthRepository>((_) => AuthRepository());
final productRepoProvider = Provider<ProductRepository>((_) => ProductRepository());
final alertRepoProvider = Provider<AlertRepository>((_) => AlertRepository());
final syncEngineProvider = Provider<SyncEngine>((_) => SyncEngine());

// Current user
final currentUserProvider = StateProvider<UserModel?>((ref) => null);

// Current branch
final currentBranchProvider = StateProvider<BranchModel?>((ref) => null);

// Device ID — generated once, persisted in SharedPreferences
final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('device_id');
  if (id == null) {
    id = const Uuid().v4();
    await prefs.setString('device_id', id);
  }
  return id;
});

// Pending sync count — refreshed every 15 s
final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  while (true) {
    yield await engine.pendingCount();
    await Future.delayed(const Duration(seconds: 15));
  }
});

// Connectivity state — reactive to actual network changes
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.instance.onlineStream;
});

// WiFi state — reactive
final isWifiProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.instance.wifiStream;
});

// WiFi-only sync preference — persisted in SharedPreferences
class WifiOnlySyncNotifier extends AsyncNotifier<bool> {
  static const _key = 'wifi_only_sync';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, !current);
    state = AsyncData(!current);
  }
}

final wifiOnlySyncProvider =
    AsyncNotifierProvider<WifiOnlySyncNotifier, bool>(WifiOnlySyncNotifier.new);
