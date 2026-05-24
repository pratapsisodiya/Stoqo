import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/sync_center/domain/sync_notifier.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class SyncCenterScreen extends ConsumerWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncNotifierProvider);
    final mutationsAsync = ref.watch(pendingMutationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: syncState.pending > 0
                            ? AppColors.warningLight
                            : AppColors.inStockBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        syncState.pending > 0
                            ? Icons.pending_outlined
                            : Icons.check_circle_outline,
                        color: syncState.pending > 0
                            ? AppColors.lowStockFg
                            : AppColors.inStockFg,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            syncState.pending > 0
                                ? '${syncState.pending} local changes'
                                : 'All changes saved',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const Text(
                            'Use WiFi Sync to share changes with another device',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/wifi-sync'),
                    icon: const Icon(Icons.wifi_tethering, size: 18),
                    label: const Text('Open WiFi Sync'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('Local Change Log',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),

          mutationsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (mutations) => mutations.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.inStockBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppColors.inStockFg),
                        SizedBox(width: 8),
                        Text('No pending changes',
                            style: TextStyle(
                                color: AppColors.inStockFg,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : Column(
                    children: mutations
                        .map((m) => _MutationTile(mutation: m))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MutationTile extends StatelessWidget {
  final Map<String, dynamic> mutation;
  const _MutationTile({required this.mutation});

  @override
  Widget build(BuildContext context) {
    final status = mutation['status'] as String? ?? 'pending';
    final (color, icon) = _statusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mutation['entity_type']} • ${mutation['operation']}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                (mutation['entity_id']?.toString() ?? '').length > 8
                    ? '${mutation['entity_id'].toString().substring(0, 8)}...'
                    : mutation['entity_id']?.toString() ?? '',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          status.toUpperCase(),
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  (Color, IconData) _statusStyle(String status) => switch (status) {
        'pending' => (AppColors.primary, Icons.schedule),
        'synced' => (AppColors.inStockFg, Icons.check_circle),
        'failed' => (AppColors.danger, Icons.error_outline),
        _ => (AppColors.textSecondary, Icons.help_outline),
      };
}
