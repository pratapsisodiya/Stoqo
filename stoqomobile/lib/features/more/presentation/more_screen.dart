import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final branch = ref.watch(currentBranchProvider);
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final isWifi = ref.watch(isWifiProvider).valueOrNull ?? false;
    final wifiOnlyAsync = ref.watch(wifiOnlySyncProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          // Profile card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  (user?.name.substring(0, 1) ?? 'U').toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'User',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(user?.role.toUpperCase() ?? '',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    if (branch != null)
                      Text(branch.name,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ]),
          ),

          // Connectivity card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isOnline ? AppColors.inStockBg : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(
                isOnline
                    ? (isWifi ? Icons.wifi : Icons.signal_cellular_alt)
                    : Icons.wifi_off,
                size: 18,
                color: isOnline ? AppColors.inStockFg : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isOnline
                      ? (isWifi
                          ? 'Connected via WiFi — ready to sync'
                          : 'Mobile data — WiFi sync needs WiFi')
                      : 'Offline — all data is saved locally',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isOnline ? AppColors.inStockFg : AppColors.danger),
                ),
              ),
            ]),
          ),

          // WiFi-only sync toggle
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.wifi, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WiFi sync only',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        'Only sync when connected to WiFi',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                wifiOnlyAsync.when(
                  data: (wifiOnly) => Switch(
                    value: wifiOnly,
                    onChanged: (_) =>
                        ref.read(wifiOnlySyncProvider.notifier).toggle(),
                    activeColor: AppColors.primary,
                  ),
                  loading: () => const SizedBox(
                      width: 32,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ]),
            ),
          ),

          _MenuItem(
            icon: Icons.wifi_tethering,
            title: 'WiFi Sync',
            subtitle: 'Share data with another device on WiFi',
            onTap: () => context.push('/wifi-sync'),
          ),
          _MenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'Purchase History',
            subtitle: 'View purchase records',
            onTap: () => context.push('/purchases'),
          ),
          _MenuItem(
            icon: Icons.swap_horiz,
            title: 'Branch Transfers',
            subtitle: 'View transfer history',
            onTap: () => context.go('/transfers'),
          ),
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.lock_outlined,
            title: 'Lock App',
            subtitle: 'Return to PIN screen',
            onTap: () {
              ref.read(authNotifierProvider.notifier).lock();
            },
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right,
          size: 18, color: AppColors.textDisabled),
      onTap: onTap,
    );
  }
}
