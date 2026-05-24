import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';
import 'package:stoqomobile/shared/widgets/bottom_nav.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final branch = ref.watch(currentBranchProvider);

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

          _MenuItem(
            icon: Icons.sync_outlined,
            title: 'Sync Center',
            subtitle: 'Manage offline sync queue',
            onTap: () => context.push('/sync-center'),
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
            icon: Icons.storefront_outlined,
            title: 'Switch Branch',
            subtitle: branch?.name ?? 'Select branch',
            onTap: () => context.push('/branch-picker'),
          ),
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Log out of this device',
            iconColor: AppColors.danger,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => ctx.pop(false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => ctx.pop(true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(authNotifierProvider.notifier).logout();
                context.go('/login');
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textDisabled),
      onTap: onTap,
    );
  }
}
