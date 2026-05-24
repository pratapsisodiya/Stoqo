import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/quantity_chip.dart';

class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanning = true;
  ProductModel? _scannedProduct;
  String? _scannedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final code = barcode!.rawValue!;
    if (code == _scannedCode) return;

    setState(() { _scanning = false; _scannedCode = code; });
    await _controller.stop();

    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;

    final product = await ref.read(productRepoProvider).getByBarcode(branch.id, code);
    if (mounted) {
      setState(() => _scannedProduct = product);
    }
  }

  void _reset() {
    setState(() {
      _scanning = true;
      _scannedProduct = null;
      _scannedCode = null;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Scan overlay
                Center(
                  child: Container(
                    width: 240,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _scannedProduct != null
                              ? AppColors.secondary
                              : AppColors.primary,
                          width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_scanning)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Point camera at a barcode',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _scannedCode == null
                ? const Center(
                    child: Text('Scan a barcode to see product details',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : _ProductSheet(
                    barcode: _scannedCode!,
                    product: _scannedProduct,
                    onReset: _reset,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductSheet extends ConsumerWidget {
  final String barcode;
  final ProductModel? product;
  final VoidCallback onReset;

  const _ProductSheet({
    required this.barcode,
    required this.product,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (product == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text('No product found for barcode:\n$barcode',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onReset, child: const Text('Scan Again')),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product!.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('SKU: ${product!.sku}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            QuantityChip(product: product!),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Stock In'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary),
                onPressed: () => context.push(
                    '/stock-update?type=stock_in&product_id=${product!.id}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('Stock Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                onPressed: () => context.push(
                    '/stock-update?type=stock_out&product_id=${product!.id}'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () =>
                  context.push('/products/${product!.id}'),
              child: const Icon(Icons.info_outline),
            ),
          ]),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.qr_code_scanner, size: 16),
              label: const Text('Scan Again'),
              onPressed: onReset,
            ),
          ),
        ],
      ),
    );
  }
}
