import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final ProductModel product;
  const EditProductScreen({super.key, required this.product});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _sellCtrl;
  late final TextEditingController _minStockCtrl;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p.name);
    _skuCtrl = TextEditingController(text: p.sku);
    _barcodeCtrl = TextEditingController(text: p.barcode ?? '');
    _categoryCtrl = TextEditingController(text: p.category ?? '');
    _unitCtrl = TextEditingController(text: p.unit);
    _costCtrl = TextEditingController(text: p.costPrice.toStringAsFixed(0));
    _sellCtrl = TextEditingController(text: p.sellingPrice.toStringAsFixed(0));
    _minStockCtrl = TextEditingController(text: p.minStockLevel.toString());
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _skuCtrl, _barcodeCtrl, _categoryCtrl, _unitCtrl,
      _costCtrl, _sellCtrl, _minStockCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final updated = widget.product.copyWith(
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().isEmpty ? widget.product.sku : _skuCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
        costPrice: double.tryParse(_costCtrl.text) ?? widget.product.costPrice,
        sellingPrice: double.tryParse(_sellCtrl.text) ?? widget.product.sellingPrice,
        minStockLevel: int.tryParse(_minStockCtrl.text) ?? widget.product.minStockLevel,
      );

      await ref.read(productRepoProvider).updateProduct(updated);

      ref.invalidate(productListProvider);
      ref.invalidate(productDetailProvider(widget.product.id));
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Product updated'),
              backgroundColor: AppColors.secondary),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
            'Delete "${widget.product.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => ctx.pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await ref.read(productRepoProvider).deleteProduct(widget.product.id);
    ref.invalidate(productListProvider);
    ref.invalidate(dashboardStatsProvider);

    if (mounted) context.go('/products');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Delete',
            onPressed: _delete,
          ),
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section('Basic Info', [
              _Field(_nameCtrl, 'Product name *', Icons.inventory_2_outlined,
                  required: true, caps: TextCapitalization.words),
              _Field(_skuCtrl, 'SKU', Icons.qr_code),
              _Field(_barcodeCtrl, 'Barcode (optional)', Icons.barcode_reader),
              _Field(_categoryCtrl, 'Category (optional)', Icons.category_outlined,
                  caps: TextCapitalization.words),
              _Field(_unitCtrl, 'Unit', Icons.straighten_outlined),
            ]),
            const SizedBox(height: 16),
            _Section('Pricing', [
              _NumField(_costCtrl, 'Cost price (Rp)', Icons.price_change_outlined),
              _NumField(_sellCtrl, 'Selling price (Rp)', Icons.sell_outlined),
            ]),
            const SizedBox(height: 16),
            _Section('Stock', [
              _NumField(_minStockCtrl, 'Minimum stock level (for alerts)',
                  Icons.warning_amber_outlined),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ...children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: c,
            )),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final TextCapitalization caps;
  const _Field(this.ctrl, this.label, this.icon,
      {this.required = false, this.caps = TextCapitalization.none});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      textCapitalization: caps,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  const _NumField(this.ctrl, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        if (double.tryParse(v) == null) return 'Must be a number';
        return null;
      },
    );
  }
}
