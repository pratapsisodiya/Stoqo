class BranchModel {
  final String id;
  final String name;
  final String code;
  final String? address;
  final String? syncCursor;
  final DateTime? lastSyncedAt;

  const BranchModel({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.syncCursor,
    this.lastSyncedAt,
  });

  factory BranchModel.fromJson(Map<String, dynamic> j) => BranchModel(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        address: j['address'] as String?,
        syncCursor: j['sync_cursor'] as String?,
        lastSyncedAt: j['last_synced_at'] != null
            ? DateTime.tryParse(j['last_synced_at'] as String)
            : null,
      );

  factory BranchModel.fromDb(Map<String, dynamic> row) => BranchModel(
        id: row['id'] as String,
        name: row['name'] as String,
        code: row['code'] as String,
        address: row['address'] as String?,
        syncCursor: row['sync_cursor'] as String?,
        lastSyncedAt: row['last_synced_at'] != null
            ? DateTime.tryParse(row['last_synced_at'] as String)
            : null,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'name': name,
        'code': code,
        'address': address,
        'sync_cursor': syncCursor,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
      };
}
