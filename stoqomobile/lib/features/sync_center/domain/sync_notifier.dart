import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/core/sync/sync_engine.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

class SyncState {
  final int pending;
  final DateTime? lastSyncedAt;
  final String? error;

  const SyncState({
    this.pending = 0,
    this.lastSyncedAt,
    this.error,
  });

  SyncState copyWith({int? pending, DateTime? lastSyncedAt, String? error}) =>
      SyncState(
        pending: pending ?? this.pending,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        error: error,
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  final SyncEngine _engine;

  SyncNotifier(this._engine) : super(const SyncState()) {
    _loadPending();
  }

  Future<void> _loadPending() async {
    final count = await _engine.pendingCount();
    if (mounted) state = state.copyWith(pending: count);
  }

  Future<void> refresh() => _loadPending();
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref.watch(syncEngineProvider));
});

final pendingMutationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(syncEngineProvider).pendingMutations();
});
