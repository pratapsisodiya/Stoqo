import 'package:flutter/material.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class QuantityChip extends StatelessWidget {
  final ProductModel product;
  const QuantityChip({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    if (product.isOutOfStock) {
      bg = AppColors.outOfStockBg;
      fg = AppColors.outOfStockFg;
      label = 'Out of stock';
    } else if (product.isLowStock) {
      bg = AppColors.lowStockBg;
      fg = AppColors.lowStockFg;
      label = '${product.currentQuantity} ${product.unit} ⚠';
    } else {
      bg = AppColors.inStockBg;
      fg = AppColors.inStockFg;
      label = '${product.currentQuantity} ${product.unit}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
