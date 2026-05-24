import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/core/constants/app_constants.dart';
import 'package:stoqomobile/core/utils/date_utils.dart';
import 'package:stoqomobile/features/alerts/domain/alert_notifier.dart';
import 'package:stoqomobile/features/alerts/domain/models/alert_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/empty_state_widget.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final branch = ref.watch(currentBranchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (branch != null)
            TextButton(
              onPressed: () =>
                  ref.read(alertsProvider.notifier).markAllRead(branch.id),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (alerts) => alerts.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.notifications_none,
                title: 'No alerts',
                subtitle: 'You\'re all caught up!',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(alertsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _AlertTile(alert: alerts[i]),
                ),
              ),
      ),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  final AlertModel alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (bg, fg, icon) = _style(alert.type);
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.secondary,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.done, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(alertsProvider.notifier).markRead(alert.id),
      child: Container(
        color: alert.isRead ? null : bg.withOpacity(0.3),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 20),
          ),
          title: Text(
            AppConstants.alertTypeLabels[alert.type] ?? alert.type,
            style: TextStyle(
                fontWeight:
                    alert.isRead ? FontWeight.w400 : FontWeight.w700,
                fontSize: 13),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.message,
                  style: const TextStyle(fontSize: 12)),
              Text(AppDateUtils.timeAgo(alert.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textDisabled)),
            ],
          ),
          trailing: alert.isRead
              ? null
              : Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
          onTap: () {
            if (!alert.isRead) {
              ref.read(alertsProvider.notifier).markRead(alert.id);
            }
          },
        ),
      ),
    );
  }

  (Color, Color, IconData) _style(String type) {
    return switch (type) {
      'low_stock' => (AppColors.warningLight, AppColors.lowStockFg, Icons.warning_amber),
      'out_of_stock' => (AppColors.dangerLight, AppColors.danger, Icons.block),
      'sync_failed' => (AppColors.dangerLight, AppColors.danger, Icons.sync_problem),
      'transfer_pending' => (AppColors.primaryLight, AppColors.primary, Icons.swap_horiz),
      _ => (AppColors.background, AppColors.textSecondary, Icons.info_outline),
    };
  }
}
