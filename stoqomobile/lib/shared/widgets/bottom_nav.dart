import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  static const _tabs = [
    (icon: Icons.dashboard_outlined, label: 'Home', path: '/'),
    (icon: Icons.inventory_2_outlined, label: 'Products', path: '/products'),
    (icon: Icons.qr_code_scanner, label: 'Scan', path: '/scan'),
    (icon: Icons.swap_horiz, label: 'Transfers', path: '/transfers'),
    (icon: Icons.more_horiz, label: 'More', path: '/more'),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryLight,
      onDestinationSelected: (i) => context.go(_tabs[i].path),
      destinations: _tabs
          .map((t) => NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              ))
          .toList(),
    );
  }
}
