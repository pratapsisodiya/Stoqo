import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/core/utils/date_utils.dart';
import 'package:stoqomobile/features/purchases/data/purchase_repository.dart';
import 'package:stoqomobile/features/purchases/domain/models/purchase_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/empty_state_widget.dart';

final _purchasesProvider =
    FutureProvider.autoDispose<List<PurchaseModel>>((ref) async {
  final branch = ref.watch(currentBranchProvider);
  if (branch == null) return [];
  final repo = PurchaseRepository();
  await repo.syncFromServer(branch.id);
  return repo.getPurchases(branch.id);
});

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(_purchasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase History')),
      body: purchasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (purchases) => purchases.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: 'No purchases yet',
                subtitle: 'Purchase history will appear here',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_purchasesProvider),
                child: ListView.builder(
                  itemCount: purchases.length,
                  itemBuilder: (context, i) =>
                      _PurchaseTile(purchase: purchases[i]),
                ),
              ),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final PurchaseModel purchase;
  const _PurchaseTile({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  purchase.supplierName ?? 'Unknown Supplier',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                'Rp ${purchase.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary),
              ),
            ]),
            if (purchase.invoiceNumber != null)
              Text('Invoice: ${purchase.invoiceNumber}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.category_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${purchase.items.length} items',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Text(AppDateUtils.formatDate(purchase.purchaseDate),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textDisabled)),
            ]),
          ],
        ),
      ),
    );
  }
}
