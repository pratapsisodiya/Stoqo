import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/core/utils/date_utils.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/features/inventory/domain/models/movement_model.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/quantity_chip.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    final branch = ref.watch(currentBranchProvider);

    return productAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Error: $e'))),
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Product not found')),
          );
        }
        return _ProductDetailView(product: product, branchId: branch?.id ?? '');
      },
    );
  }
}

class _ProductDetailView extends ConsumerWidget {
  final ProductModel product;
  final String branchId;
  const _ProductDetailView({required this.product, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync =
        ref.watch(movementsProvider((branchId, product.id)));

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/products/${product.id}/edit', extra: product),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Header card
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            if (product.category != null)
                              Text(product.category!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                          ],
                        ),
                      ),
                      QuantityChip(product: product),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _InfoRow('SKU', product.sku),
                  if (product.barcode != null)
                    _InfoRow('Barcode', product.barcode!),
                  _InfoRow('Unit', product.unit),
                  _InfoRow('Cost Price', 'Rp ${product.costPrice.toStringAsFixed(0)}'),
                  _InfoRow('Selling Price', 'Rp ${product.sellingPrice.toStringAsFixed(0)}'),
                  _InfoRow('Min Stock', product.minStockLevel.toString()),
                  if (product.updatedAt != null)
                    _InfoRow('Last Updated', AppDateUtils.formatDateTime(product.updatedAt)),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Stock In'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary),
                  onPressed: () => context.push(
                      '/stock-update?type=stock_in&product_id=${product.id}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Stock Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: () => context.push(
                      '/stock-update?type=stock_out&product_id=${product.id}'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => context.push(
                    '/stock-update?type=adjustment&product_id=${product.id}'),
                child: const Text('Adjust'),
              ),
            ]),
          ),

          // Movement history
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('Movement History',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          movementsAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (movements) => movements.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No movements yet',
                        style: TextStyle(color: AppColors.textDisabled)))
                : Column(
                    children: movements
                        .map((m) => _MovementTile(movement: m))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final MovementModel movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isPositive = {
      'stock_in', 'transfer_in', 'purchase', 'return'
    }.contains(movement.type);
    final color = isPositive ? AppColors.secondary : AppColors.danger;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPositive ? Icons.arrow_downward : Icons.arrow_upward,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movement.type.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              if (movement.reason != null)
                Text(movement.reason!,
                    style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : '-'}${movement.quantity}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
            Text(
              AppDateUtils.formatDate(movement.createdAt),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ]),
    );
  }
}
