import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/features/alerts/domain/models/alert_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

class AlertsNotifier extends AsyncNotifier<List<AlertModel>> {
  @override
  Future<List<AlertModel>> build() async {
    final branch = ref.watch(currentBranchProvider);
    if (branch == null) return [];
    return ref.watch(alertRepoProvider).getAlerts(branch.id);
  }

  Future<void> markRead(String alertId) async {
    await ref.watch(alertRepoProvider).markRead(alertId);
    ref.invalidateSelf();
  }

  Future<void> markAllRead(String branchId) async {
    await ref.watch(alertRepoProvider).markAllRead(branchId);
    ref.invalidateSelf();
  }
}

final alertsProvider = AsyncNotifierProvider<AlertsNotifier, List<AlertModel>>(
  AlertsNotifier.new,
);

final unreadAlertCountProvider = FutureProvider<int>((ref) async {
  final branch = ref.watch(currentBranchProvider);
  if (branch == null) return 0;
  return ref.watch(alertRepoProvider).unreadCount(branch.id);
});
