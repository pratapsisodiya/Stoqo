class ProductModel {
  final String id;
  final String branchId;
  final String sku;
  final String? barcode;
  final String name;
  final String? category;
  final String unit;
  final double costPrice;
  final double sellingPrice;
  final int minStockLevel;
  final int currentQuantity;
  final int version;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDirty;

  const ProductModel({
    required this.id,
    required this.branchId,
    required this.sku,
    this.barcode,
    required this.name,
    this.category,
    required this.unit,
    required this.costPrice,
    required this.sellingPrice,
    required this.minStockLevel,
    required this.currentQuantity,
    required this.version,
    this.updatedAt,
    this.deletedAt,
    this.isDirty = false,
  });

  bool get isLowStock => currentQuantity <= minStockLevel && minStockLevel > 0;
  bool get isOutOfStock => currentQuantity <= 0;

  factory ProductModel.fromDb(Map<String, dynamic> row) => ProductModel(
        id: row['id'] as String,
        branchId: row['branch_id'] as String,
        sku: row['sku'] as String,
        barcode: row['barcode'] as String?,
        name: row['name'] as String,
        category: row['category'] as String?,
        unit: row['unit'] as String? ?? 'pcs',
        costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
        sellingPrice: (row['selling_price'] as num?)?.toDouble() ?? 0,
        minStockLevel: row['min_stock_level'] as int? ?? 0,
        currentQuantity: row['current_quantity'] as int? ?? 0,
        version: row['version'] as int? ?? 1,
        updatedAt: row['updated_at'] != null
            ? DateTime.tryParse(row['updated_at'] as String)
            : null,
        deletedAt: row['deleted_at'] != null
            ? DateTime.tryParse(row['deleted_at'] as String)
            : null,
        isDirty: (row['is_dirty'] as int?) == 1,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'branch_id': branchId,
        'sku': sku,
        'barcode': barcode,
        'name': name,
        'category': category,
        'unit': unit,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'min_stock_level': minStockLevel,
        'current_quantity': currentQuantity,
        'version': version,
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_dirty': isDirty ? 1 : 0,
      };

  ProductModel copyWith({
    String? sku,
    String? barcode,
    String? name,
    String? category,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    int? minStockLevel,
    int? currentQuantity,
    int? version,
    bool? isDirty,
  }) =>
      ProductModel(
        id: id,
        branchId: branchId,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        costPrice: costPrice ?? this.costPrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        minStockLevel: minStockLevel ?? this.minStockLevel,
        currentQuantity: currentQuantity ?? this.currentQuantity,
        version: version ?? this.version,
        updatedAt: DateTime.now(),
        deletedAt: deletedAt,
        isDirty: isDirty ?? this.isDirty,
      );
}
