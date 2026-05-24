class TransferItemModel {
  final String id;
  final String transferId;
  final String productId;
  final int quantity;
  final int? receivedQuantity;

  const TransferItemModel({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.quantity,
    this.receivedQuantity,
  });

  factory TransferItemModel.fromDb(Map<String, dynamic> row) => TransferItemModel(
        id: row['id'] as String,
        transferId: row['transfer_id'] as String,
        productId: row['product_id'] as String,
        quantity: row['quantity'] as int,
        receivedQuantity: row['received_quantity'] as int?,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'transfer_id': transferId,
        'product_id': productId,
        'quantity': quantity,
        'received_quantity': receivedQuantity,
      };
}

class TransferModel {
  final String id;
  final String fromBranchId;
  final String toBranchId;
  final String status;
  final String? notes;
  final String? createdBy;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? receivedAt;
  final List<TransferItemModel> items;

  const TransferModel({
    required this.id,
    required this.fromBranchId,
    required this.toBranchId,
    required this.status,
    this.notes,
    this.createdBy,
    this.approvedBy,
    required this.createdAt,
    this.approvedAt,
    this.receivedAt,
    this.items = const [],
  });

  factory TransferModel.fromDb(Map<String, dynamic> row,
      {List<TransferItemModel> items = const []}) =>
      TransferModel(
        id: row['id'] as String,
        fromBranchId: row['from_branch_id'] as String,
        toBranchId: row['to_branch_id'] as String,
        status: row['status'] as String? ?? 'pending',
        notes: row['notes'] as String?,
        createdBy: row['created_by'] as String?,
        approvedBy: row['approved_by'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        approvedAt: row['approved_at'] != null
            ? DateTime.tryParse(row['approved_at'] as String)
            : null,
        receivedAt: row['received_at'] != null
            ? DateTime.tryParse(row['received_at'] as String)
            : null,
        items: items,
      );
}
