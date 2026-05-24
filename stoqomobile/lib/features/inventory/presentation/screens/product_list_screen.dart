import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/bottom_nav.dart';
import 'package:stoqomobile/shared/widgets/empty_state_widget.dart';
import 'package:stoqomobile/shared/widgets/quantity_chip.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  final String? filterParam;
  const ProductListScreen({super.key, this.filterParam});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    if (widget.filterParam == 'low_stock' || widget.filterParam == 'out_of_stock') {
      ref.read(productListProvider.notifier).toggleLowStock(branch.id);
    } else {
      ref.read(productListProvider.notifier).load(branch.id);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final state = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (state.lowStockOnly)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Low stock',
                  style: TextStyle(fontSize: 12, color: AppColors.lowStockFg)),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              if (branch != null) {
                ref.read(productListProvider.notifier).toggleLowStock(branch.id);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by name, SKU or barcode...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (q) {
                if (branch != null) {
                  ref.read(productListProvider.notifier).setQuery(q, branch.id);
                }
              },
            ),
          ),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.products.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products found',
                        subtitle: state.query.isNotEmpty
                            ? 'Try a different search term'
                            : 'Tap + to add your first product',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (branch != null) {
                            await ref
                                .read(productListProvider.notifier)
                                .load(branch.id);
                          }
                        },
                        child: ListView.builder(
                          itemCount: state.products.length,
                          itemBuilder: (context, i) =>
                              _ProductTile(product: state.products[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-product');
          if (context.mounted) {
            final b = ref.read(currentBranchProvider);
            if (b != null) ref.read(productListProvider.notifier).load(b.id);
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              product.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
          ),
        ),
        title: Text(product.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${product.sku}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            if (product.category != null)
              Text(product.category!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        trailing: QuantityChip(product: product),
        onTap: () => context.push('/products/${product.id}'),
      ),
    );
  }
}
