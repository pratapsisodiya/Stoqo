import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/core/constants/app_constants.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/quantity_chip.dart';

class StockUpdateScreen extends ConsumerStatefulWidget {
  final String type;
  final String? productId;

  const StockUpdateScreen({super.key, required this.type, this.productId});

  @override
  ConsumerState<StockUpdateScreen> createState() => _StockUpdateScreenState();
}

class _StockUpdateScreenState extends ConsumerState<StockUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  String _type = 'stock_in';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(ProductModel product) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final branch = ref.read(currentBranchProvider);
      final user = ref.read(currentUserProvider);
      final deviceId = await ref.read(deviceIdProvider.future);

      await ref.read(productRepoProvider).applyMovement(
        branchId: branch!.id,
        product: product,
        type: _type,
        quantity: int.parse(_qtyCtrl.text.trim()),
        deviceId: deviceId,
        userId: user?.id ?? '',
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock updated: ${AppConstants.movementTypeLabels[_type]}'),
            backgroundColor: AppColors.secondary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = widget.productId != null
        ? ref.watch(productDetailProvider(widget.productId!))
        : const AsyncData<ProductModel?>(null);

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppConstants.movementTypeLabels[_type]}'),
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (product) => _buildForm(product),
      ),
    );
  }

  Widget _buildForm(ProductModel? product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product != null) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          Text('SKU: ${product.sku}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    QuantityChip(product: product),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Movement type selector
            const Text('Movement Type',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.movementTypes.map((type) {
                final selected = _type == type;
                return ChoiceChip(
                  label: Text(AppConstants.movementTypeLabels[type] ?? type),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = type),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = int.tryParse(v);
                if (n == null || n <= 0) return 'Must be a positive number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: product == null || _loading ? null : () => _submit(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: _type == 'stock_in'
                    ? AppColors.secondary
                    : _type == 'stock_out'
                        ? AppColors.danger
                        : AppColors.primary,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save ${AppConstants.movementTypeLabels[_type]}'),
            ),
          ],
        ),
      ),
    );
  }
}
