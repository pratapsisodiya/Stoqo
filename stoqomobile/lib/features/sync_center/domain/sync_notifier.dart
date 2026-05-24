import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/core/sync/sync_engine.dart';
import 'package:stoqomobile/features/alerts/domain/alert_notifier.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

class SyncState {
  final bool syncing;
  final int pending;
  final int conflicted;
  final DateTime? lastSyncedAt;
  final String? error;

  const SyncState({
    this.syncing = false,
    this.pending = 0,
    this.conflicted = 0,
    this.lastSyncedAt,
    this.error,
  });

  SyncState copyWith({
    bool? syncing,
    int? pending,
    int? conflicted,
    DateTime? lastSyncedAt,
    String? error,
  }) =>
      SyncState(
        syncing: syncing ?? this.syncing,
        pending: pending ?? this.pending,
        conflicted: conflicted ?? this.conflicted,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        error: error,
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  final SyncEngine _engine;
  final Ref _ref;

  SyncNotifier(this._engine, this._ref) : super(const SyncState()) {
    _loadPending();
  }

  Future<void> _loadPending() async {
    final count = await _engine.pendingCount();
    if (mounted) state = state.copyWith(pending: count);
  }

  Future<void> syncNow() async {
    final branch = _ref.read(currentBranchProvider);
    if (branch == null || state.syncing) return;

    if (mounted) state = state.copyWith(syncing: true, error: null);
    try {
      final deviceId = await _ref.read(deviceIdProvider.future);
      final result = await _engine.pushAll(deviceId);
      await _engine.pullDelta(branch.id, branch.syncCursor);

      final pending = await _engine.pendingCount();
      if (mounted) {
        state = state.copyWith(
          syncing: false,
          pending: pending,
          conflicted: result.conflicted,
          lastSyncedAt: DateTime.now(),
        );
      }

      // Refresh UI from the newly-pulled local DB data
      _ref.invalidate(productListProvider);
      _ref.invalidate(alertsProvider);
      _ref.invalidate(unreadAlertCountProvider);
    } catch (e) {
      if (mounted) state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  Future<void> refresh() => _loadPending();
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref.watch(syncEngineProvider), ref);
});

final pendingMutationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(syncEngineProvider).pendingMutations();
});
