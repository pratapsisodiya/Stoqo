import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/features/auth/presentation/screens/branch_picker_screen.dart';
import 'package:stoqomobile/features/auth/presentation/screens/login_screen.dart';
import 'package:stoqomobile/features/barcode/presentation/screens/barcode_scan_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/dashboard_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/product_detail_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/product_list_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/stock_update_screen.dart';
import 'package:stoqomobile/features/more/presentation/more_screen.dart';
import 'package:stoqomobile/features/purchases/presentation/screens/purchases_screen.dart';
import 'package:stoqomobile/features/sync_center/presentation/screens/sync_center_screen.dart';
import 'package:stoqomobile/features/transfers/presentation/screens/transfers_screen.dart';
import 'package:stoqomobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:stoqomobile/shared/theme/app_theme.dart';

class StoqoApp extends ConsumerWidget {
  const StoqoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final router = _buildRouter(ref, authState);
    return MaterialApp.router(
      title: 'Stoqo',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  GoRouter _buildRouter(WidgetRef ref, AuthState authState) {
    return GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final isSplash = state.matchedLocation == '/splash';
        if (isSplash) return null;

        final loggedIn = authState.status == AuthStatus.authenticated;
        final isLogin = state.matchedLocation == '/login';
        if (!loggedIn && !isLogin) return '/login';
        if (loggedIn && isLogin) return '/branch-picker';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/branch-picker',
          builder: (_, __) => const BranchPickerScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/products',
          builder: (_, state) => ProductListScreen(
            filterParam: state.uri.queryParameters['filter'],
          ),
        ),
        GoRoute(
          path: '/products/:id',
          builder: (_, state) =>
              ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/scan',
          builder: (_, __) => const BarcodeScanScreen(),
        ),
        GoRoute(
          path: '/stock-update',
          builder: (_, state) => StockUpdateScreen(
            type: state.uri.queryParameters['type'] ?? 'stock_in',
            productId: state.uri.queryParameters['product_id'],
          ),
        ),
        GoRoute(
          path: '/transfers',
          builder: (_, __) => const TransfersScreen(),
        ),
        GoRoute(
          path: '/alerts',
          builder: (_, __) => const AlertsScreen(),
        ),
        GoRoute(
          path: '/sync-center',
          builder: (_, __) => const SyncCenterScreen(),
        ),
        GoRoute(
          path: '/purchases',
          builder: (_, __) => const PurchasesScreen(),
        ),
        GoRoute(
          path: '/more',
          builder: (_, __) => const MoreScreen(),
        ),
      ],
    );
  }
}
