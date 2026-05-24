class AppConstants {
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String deviceIdKey = 'device_id';
  static const String currentBranchKey = 'current_branch_id';
  static const String currentUserKey = 'current_user_json';

  static const List<String> movementTypes = [
    'stock_in',
    'stock_out',
    'adjustment',
  ];

  static const Map<String, String> movementTypeLabels = {
    'stock_in': 'Stock In',
    'stock_out': 'Stock Out',
    'adjustment': 'Adjustment',
    'transfer_in': 'Transfer In',
    'transfer_out': 'Transfer Out',
    'sale': 'Sale',
    'purchase': 'Purchase',
    'return': 'Return',
  };

  static const Map<String, String> alertTypeLabels = {
    'low_stock': 'Low Stock',
    'out_of_stock': 'Out of Stock',
    'sync_failed': 'Sync Failed',
    'transfer_pending': 'Transfer Pending',
  };

  static const Map<String, String> transferStatusLabels = {
    'pending': 'Pending',
    'approved': 'Approved',
    'in_transit': 'In Transit',
    'received': 'Received',
    'cancelled': 'Cancelled',
  };
}
