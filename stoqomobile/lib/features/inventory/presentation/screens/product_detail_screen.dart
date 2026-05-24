import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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

// ── Detail view ──────────────────────────────────────────────────────────────

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
            onPressed: () =>
                context.push('/products/${product.id}/edit', extra: product),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Info card ────────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          if (product.category != null)
                            Text(product.category!,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                        ],
                      ),
                    ),
                    QuantityChip(product: product),
                  ]),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _CopyRow('SKU', product.sku),
                  if (product.barcode != null)
                    _CopyRow('Barcode', product.barcode!),
                  _InfoRow('Unit', product.unit),
                  _InfoRow('Cost Price',
                      'Rp ${_fmt(product.costPrice)}'),
                  _InfoRow('Selling Price',
                      'Rp ${_fmt(product.sellingPrice)}'),
                  if (product.costPrice > 0 && product.sellingPrice > 0)
                    _InfoRow(
                      'Margin',
                      '${_margin(product.costPrice, product.sellingPrice)}%  '
                      '(Rp ${_fmt(product.sellingPrice - product.costPrice)} / unit)',
                      highlight: _marginColor(product.costPrice, product.sellingPrice),
                    ),
                  _InfoRow('Min Stock', product.minStockLevel.toString()),
                  if (product.updatedAt != null)
                    _InfoRow('Last Updated',
                        AppDateUtils.formatDateTime(product.updatedAt)),
                ],
              ),
            ),
          ),

          // ── Quick stock actions ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Expanded(
                child: _ActionButton(
                  label: 'Stock In',
                  icon: Icons.add_circle_outline,
                  color: AppColors.secondary,
                  onTap: () => _showQuickAdjust(
                      context, ref, product, branchId,
                      initialType: 'stock_in'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Stock Out',
                  icon: Icons.remove_circle_outline,
                  color: AppColors.danger,
                  onTap: () => _showQuickAdjust(
                      context, ref, product, branchId,
                      initialType: 'stock_out'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Adjust',
                  icon: Icons.tune_outlined,
                  color: AppColors.primary,
                  onTap: () => _showQuickAdjust(
                      context, ref, product, branchId,
                      initialType: 'adjustment'),
                ),
              ),
            ]),
          ),

          // ── Movement summary ─────────────────────────────────────────────
          movementsAsync.when(
            data: (movements) {
              if (movements.isEmpty) return const SizedBox.shrink();
              final positiveTypes = {
                'stock_in', 'transfer_in', 'purchase', 'return'
              };
              final totalIn = movements
                  .where((m) => positiveTypes.contains(m.type))
                  .fold(0, (s, m) => s + m.quantity);
              final totalOut = movements
                  .where((m) => !positiveTypes.contains(m.type))
                  .fold(0, (s, m) => s + m.quantity);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  _SummaryChip(
                      label: 'Total In',
                      value: '+$totalIn',
                      color: AppColors.secondary),
                  const SizedBox(width: 10),
                  _SummaryChip(
                      label: 'Total Out',
                      value: '-$totalOut',
                      color: AppColors.danger),
                  const SizedBox(width: 10),
                  _SummaryChip(
                      label: 'Net',
                      value: '${totalIn - totalOut >= 0 ? '+' : ''}${totalIn - totalOut}',
                      color: totalIn >= totalOut
                          ? AppColors.secondary
                          : AppColors.danger),
                ]),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Movement history ─────────────────────────────────────────────
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
                    children:
                        movements.map((m) => _MovementTile(m)).toList()),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(0);
  }

  String _margin(double cost, double sell) {
    if (sell == 0) return '0';
    return ((sell - cost) / sell * 100).toStringAsFixed(1);
  }

  Color _marginColor(double cost, double sell) {
    final m = sell > 0 ? (sell - cost) / sell * 100 : 0.0;
    if (m >= 30) return AppColors.secondary;
    if (m >= 10) return AppColors.warning;
    return AppColors.danger;
  }

  Future<void> _showQuickAdjust(
    BuildContext context,
    WidgetRef ref,
    ProductModel product,
    String branchId, {
    required String initialType,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _QuickAdjustSheet(
        product: product,
        initialType: initialType,
        onApply: (type, qty, reason) async {
          final user = ref.read(currentUserProvider);
          final deviceId =
              ref.read(deviceIdProvider).valueOrNull ?? 'local';
          await ref.read(productRepoProvider).applyMovement(
                branchId: branchId,
                product: product,
                type: type,
                quantity: qty,
                deviceId: deviceId,
                userId: user?.id ?? 'unknown',
                reason: reason.isEmpty ? null : reason,
              );
          ref.invalidate(productDetailProvider(product.id));
          ref.invalidate(movementsProvider((branchId, product.id)));
          ref.invalidate(productListProvider);
          ref.invalidate(dashboardStatsProvider);
        },
      ),
    );
  }
}

// ── Quick adjust bottom sheet ────────────────────────────────────────────────

class _QuickAdjustSheet extends StatefulWidget {
  final ProductModel product;
  final String initialType;
  final Future<void> Function(String type, int qty, String reason) onApply;

  const _QuickAdjustSheet({
    required this.product,
    required this.initialType,
    required this.onApply,
  });

  @override
  State<_QuickAdjustSheet> createState() => _QuickAdjustSheetState();
}

class _QuickAdjustSheetState extends State<_QuickAdjustSheet> {
  late String _type;
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _types = [
    ('stock_in', 'Stock In', AppColors.secondary),
    ('stock_out', 'Stock Out', AppColors.danger),
    ('adjustment', 'Adjust', AppColors.primary),
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onApply(_type, qty, _reasonCtrl.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Quick Update — ${widget.product.name}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Current stock: ${widget.product.currentQuantity} ${widget.product.unit}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Type selector
          Row(
            children: _types.map((t) {
              final selected = _type == t.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.$3.withOpacity(0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? t.$3 : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(t.$2,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: selected ? t.$3 : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Quantity
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: widget.product.unit,
            ),
          ),
          const SizedBox(height: 12),

          // Reason
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. damaged, sold to customer',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
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
          const Icon(Icons.copy_outlined,
              size: 13, color: AppColors.textDisabled),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;
  const _InfoRow(this.label, this.value, {this.highlight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: highlight)),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final MovementModel movement;
  const _MovementTile(this.movement);

  @override
  Widget build(BuildContext context) {
    final isPositive =
        {'stock_in', 'transfer_in', 'purchase', 'return'}.contains(movement.type);
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
              Text(
                AppDateUtils.formatDate(movement.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textDisabled),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : '-'}${movement.quantity}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
            Text(
              'bal: ${movement.quantityAfter}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textDisabled),
            ),
          ],
        ),
      ]),
    );
  }
}
