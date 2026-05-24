class PurchaseItemModel {
  final String id;
  final String purchaseId;
  final String productId;
  final int quantity;
  final double unitCost;

  const PurchaseItemModel({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
  });

  factory PurchaseItemModel.fromDb(Map<String, dynamic> row) => PurchaseItemModel(
        id: row['id'] as String,
        purchaseId: row['purchase_id'] as String,
        productId: row['product_id'] as String,
        quantity: row['quantity'] as int,
        unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'purchase_id': purchaseId,
        'product_id': productId,
        'quantity': quantity,
        'unit_cost': unitCost,
      };
}

class PurchaseModel {
  final String id;
  final String branchId;
  final String? supplierName;
  final String? invoiceNumber;
  final double totalAmount;
  final DateTime purchaseDate;
  final String? createdBy;
  final DateTime createdAt;
  final List<PurchaseItemModel> items;

  const PurchaseModel({
    required this.id,
    required this.branchId,
    this.supplierName,
    this.invoiceNumber,
    required this.totalAmount,
    required this.purchaseDate,
    this.createdBy,
    required this.createdAt,
    this.items = const [],
  });

  factory PurchaseModel.fromDb(Map<String, dynamic> row,
      {List<PurchaseItemModel> items = const []}) =>
      PurchaseModel(
        id: row['id'] as String,
        branchId: row['branch_id'] as String,
        supplierName: row['supplier_name'] as String?,
        invoiceNumber: row['invoice_number'] as String?,
        totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
        purchaseDate: DateTime.parse(row['purchase_date'] as String),
        createdBy: row['created_by'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        items: items,
      );
}
