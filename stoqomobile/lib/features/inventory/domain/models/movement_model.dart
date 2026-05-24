class MovementModel {
  final String id;
  final String productId;
  final String branchId;
  final String type;
  final int quantity;
  final int quantityBefore;
  final int quantityAfter;
  final String? reason;
  final String? referenceType;
  final String? referenceId;
  final String? createdBy;
  final DateTime createdAt;
  final String? deviceId;
  final String? mutationId;
  final bool synced;

  const MovementModel({
    required this.id,
    required this.productId,
    required this.branchId,
    required this.type,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    this.reason,
    this.referenceType,
    this.referenceId,
    this.createdBy,
    required this.createdAt,
    this.deviceId,
    this.mutationId,
    this.synced = false,
  });

  factory MovementModel.fromDb(Map<String, dynamic> row) => MovementModel(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        branchId: row['branch_id'] as String,
        type: row['type'] as String,
        quantity: row['quantity'] as int,
        quantityBefore: row['quantity_before'] as int? ?? 0,
        quantityAfter: row['quantity_after'] as int? ?? 0,
        reason: row['reason'] as String?,
        referenceType: row['reference_type'] as String?,
        referenceId: row['reference_id'] as String?,
        createdBy: row['created_by'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        deviceId: row['device_id'] as String?,
        mutationId: row['mutation_id'] as String?,
        synced: (row['synced'] as int?) == 1,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'product_id': productId,
        'branch_id': branchId,
        'type': type,
        'quantity': quantity,
        'quantity_before': quantityBefore,
        'quantity_after': quantityAfter,
        'reason': reason,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'device_id': deviceId,
        'mutation_id': mutationId,
        'synced': synced ? 1 : 0,
      };
}
