import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/alerts/domain/alert_notifier.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/features/sync_center/domain/sync_notifier.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/bottom_nav.dart';
import 'package:stoqomobile/shared/widgets/sync_status_badge.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final branch = ref.read(currentBranchProvider);
    if (branch != null) {
      ref.read(productListProvider.notifier).load(branch.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final branch = ref.watch(currentBranchProvider);
    final products = ref.watch(productListProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final alertCount = ref.watch(unreadAlertCountProvider);

    final lowStock = products.products.where((p) => p.isLowStock).length;
    final outOfStock = products.products.where((p) => p.isOutOfStock).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stoqo',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (branch != null)
              Text(branch.name,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          const SyncStatusBadge(),
          const SizedBox(width: 8),
          IconButton(
            icon: Stack(children: [
              const Icon(Icons.notifications_outlined),
              alertCount.when(
                data: (c) => c > 0
                    ? Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.danger, shape: BoxShape.circle),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ]),
            onPressed: () => context.push('/alerts'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Greeting
            Text('Hello, ${user?.name.split(' ').first ?? 'there'} 👋',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              branch != null ? branch.name : 'No branch selected',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Stat cards
            Row(children: [
              Expanded(
                  child: _StatCard(
                icon: Icons.warning_amber_outlined,
                label: 'Low Stock',
                value: lowStock.toString(),
                color: AppColors.warningLight,
                iconColor: AppColors.lowStockFg,
                onTap: () => context.push('/products?filter=low_stock'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                icon: Icons.block_outlined,
                label: 'Out of Stock',
                value: outOfStock.toString(),
                color: AppColors.dangerLight,
                iconColor: AppColors.danger,
                onTap: () => context.push('/products?filter=out_of_stock'),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _StatCard(
                icon: Icons.sync_outlined,
                label: 'Pending Sync',
                value: syncState.pending.toString(),
                color: syncState.pending > 0
                    ? AppColors.warningLight
                    : AppColors.inStockBg,
                iconColor: syncState.pending > 0
                    ? AppColors.lowStockFg
                    : AppColors.inStockFg,
                onTap: () => context.push('/sync-center'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                value: products.products.length.toString(),
                color: AppColors.primaryLight,
                iconColor: AppColors.primary,
                onTap: () => context.go('/products'),
              )),
            ]),

            const SizedBox(height: 24),

            // Quick actions
            const Text('Quick Actions',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _QuickAction(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan',
                    color: AppColors.primary,
                    onTap: () => context.go('/scan')),
                _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Stock In',
                    color: AppColors.secondary,
                    onTap: () => context.push('/stock-update?type=stock_in')),
                _QuickAction(
                    icon: Icons.remove_circle_outline,
                    label: 'Stock Out',
                    color: AppColors.danger,
                    onTap: () => context.push('/stock-update?type=stock_out')),
                _QuickAction(
                    icon: Icons.swap_horiz,
                    label: 'Transfer',
                    color: AppColors.primary,
                    onTap: () => context.go('/transfers')),
                _QuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Purchase',
                    color: AppColors.textSecondary,
                    onTap: () => context.push('/purchases')),
                _QuickAction(
                    icon: Icons.notifications_outlined,
                    label: 'Alerts',
                    color: AppColors.warning,
                    onTap: () => context.push('/alerts')),
              ],
            ),

            const SizedBox(height: 24),

            // Sync status
            if (syncState.lastSyncedAt != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inStockBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.inStockFg),
                  const SizedBox(width: 8),
                  Text(
                    'Last synced ${_ago(syncState.lastSyncedAt!)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inStockFg),
                  ),
                ]),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: iconColor)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
