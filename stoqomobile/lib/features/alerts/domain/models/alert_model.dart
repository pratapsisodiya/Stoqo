class AlertModel {
  final String id;
  final String branchId;
  final String? productId;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AlertModel({
    required this.id,
    required this.branchId,
    this.productId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AlertModel.fromDb(Map<String, dynamic> row) => AlertModel(
        id: row['id'] as String,
        branchId: row['branch_id'] as String,
        productId: row['product_id'] as String?,
        type: row['type'] as String,
        message: row['message'] as String,
        isRead: (row['is_read'] as int?) == 1,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
        id: j['id'] as String,
        branchId: j['branch_id'] as String,
        productId: j['product_id'] as String?,
        type: j['type'] as String,
        message: j['message'] as String,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
