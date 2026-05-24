import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/core/constants/app_constants.dart';
import 'package:stoqomobile/core/utils/date_utils.dart';
import 'package:stoqomobile/features/transfers/data/transfer_repository.dart';
import 'package:stoqomobile/features/transfers/domain/models/transfer_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/empty_state_widget.dart';

final _transfersProvider = FutureProvider.autoDispose<List<TransferModel>>((ref) async {
  final branch = ref.watch(currentBranchProvider);
  if (branch == null) return [];
  final repo = TransferRepository();
  return repo.getTransfers(branch.id);
});

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfersAsync = ref.watch(_transfersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
      ),
      body: transfersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (transfers) => transfers.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.swap_horiz,
                title: 'No transfers',
                subtitle: 'Branch transfers will appear here',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_transfersProvider),
                child: ListView.builder(
                  itemCount: transfers.length,
                  itemBuilder: (context, i) =>
                      _TransferTile(transfer: transfers[i]),
                ),
              ),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  final TransferModel transfer;
  const _TransferTile({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _statusStyle(transfer.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  'Transfer #${transfer.id.substring(0, 8)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  AppConstants.transferStatusLabels[transfer.status] ??
                      transfer.status,
                  style: TextStyle(
                      color: fg, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.circle, size: 8, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('From: ${transfer.fromBranchId.substring(0, 8)}...',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.circle, size: 8, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text('To: ${transfer.toBranchId.substring(0, 8)}...',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.category_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${transfer.items.length} items',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Text(AppDateUtils.formatDate(transfer.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textDisabled)),
            ]),
          ],
        ),
      ),
    );
  }

  (Color, Color) _statusStyle(String status) => switch (status) {
        'pending' => (AppColors.warningLight, AppColors.lowStockFg),
        'approved' => (AppColors.primaryLight, AppColors.primary),
        'in_transit' => (AppColors.primaryLight, AppColors.primary),
        'received' => (AppColors.inStockBg, AppColors.inStockFg),
        'cancelled' => (AppColors.dangerLight, AppColors.danger),
        _ => (AppColors.background, AppColors.textSecondary),
      };
}
