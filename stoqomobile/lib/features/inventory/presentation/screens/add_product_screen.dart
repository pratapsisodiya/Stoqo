import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  final _costCtrl = TextEditingController(text: '0');
  final _sellCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '0');
  final _initialQtyCtrl = TextEditingController(text: '0');

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _skuCtrl, _barcodeCtrl, _categoryCtrl, _unitCtrl,
      _costCtrl, _sellCtrl, _minStockCtrl, _initialQtyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      setState(() { _loading = false; _error = 'No branch selected'; });
      return;
    }

    try {
      await ref.read(productRepoProvider).createProduct(
        branchId: branch.id,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
        costPrice: double.tryParse(_costCtrl.text) ?? 0,
        sellingPrice: double.tryParse(_sellCtrl.text) ?? 0,
        minStockLevel: int.tryParse(_minStockCtrl.text) ?? 0,
        initialQuantity: int.tryParse(_initialQtyCtrl.text) ?? 0,
      );

      ref.invalidate(productListProvider);
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added'), backgroundColor: AppColors.secondary),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
        actions: [
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
              _Field(_skuCtrl, 'SKU (leave blank to auto-generate)', Icons.qr_code),
              _Field(_barcodeCtrl, 'Barcode (optional)', Icons.barcode_reader),
              _Field(_categoryCtrl, 'Category (optional)', Icons.category_outlined,
                  caps: TextCapitalization.words),
              _Field(_unitCtrl, 'Unit (pcs, kg, box…)', Icons.straighten_outlined),
            ]),
            const SizedBox(height: 16),
            _Section('Pricing', [
              _NumField(_costCtrl, 'Cost price (Rp)', Icons.price_change_outlined),
              _NumField(_sellCtrl, 'Selling price (Rp)', Icons.sell_outlined),
            ]),
            const SizedBox(height: 16),
            _Section('Stock', [
              _NumField(_initialQtyCtrl, 'Opening stock quantity', Icons.numbers),
              _NumField(_minStockCtrl, 'Minimum stock level (for alerts)', Icons.warning_amber_outlined),
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
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon)),
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
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon)),
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        if (double.tryParse(v) == null) return 'Must be a number';
        return null;
      },
    );
  }
}
