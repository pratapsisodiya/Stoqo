import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/add_product_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/dashboard_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/edit_product_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/product_detail_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/product_list_screen.dart';
import 'package:stoqomobile/features/inventory/presentation/screens/stock_update_screen.dart';
import 'package:stoqomobile/features/barcode/presentation/screens/barcode_scan_screen.dart';
import 'package:stoqomobile/features/more/presentation/more_screen.dart';
import 'package:stoqomobile/features/purchases/presentation/screens/purchases_screen.dart';
import 'package:stoqomobile/features/setup/presentation/first_run_screen.dart';
import 'package:stoqomobile/features/setup/presentation/pin_unlock_screen.dart';
import 'package:stoqomobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:stoqomobile/features/sync_center/presentation/screens/sync_center_screen.dart';
import 'package:stoqomobile/features/transfers/presentation/screens/transfers_screen.dart';
import 'package:stoqomobile/features/wifi_sync/presentation/wifi_sync_screen.dart';
import 'package:stoqomobile/shared/theme/app_theme.dart';
import 'package:stoqomobile/shared/widgets/offline_banner.dart';
import 'package:stoqomobile/shared/widgets/main_shell.dart';

class StoqoApp extends ConsumerWidget {
  const StoqoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final router = _buildRouter(authState, ref);
    return MaterialApp.router(
      title: 'Stoqo',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }

  GoRouter _buildRouter(AuthState authState, WidgetRef ref) {
    return GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final loc = state.matchedLocation;

        if (loc == '/splash') return null;

        switch (authState.status) {
          case AuthStatus.loading:
            return '/splash';
          case AuthStatus.firstRun:
            if (loc == '/setup') return null;
            return '/setup';
          case AuthStatus.locked:
            if (loc == '/unlock') return null;
            return '/unlock';
          case AuthStatus.authenticated:
            if (loc == '/setup' || loc == '/unlock') return '/';
            return null;
        }
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/setup', builder: (_, __) => const FirstRunScreen()),
        GoRoute(path: '/unlock', builder: (_, __) => const PinUnlockScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShellScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const DashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/products',
                  builder: (_, state) => ProductListScreen(
                      filterParam: state.uri.queryParameters['filter']),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/scan',
                  builder: (_, __) => const BarcodeScanScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/transfers',
                  builder: (_, __) => const TransfersScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/more',
                  builder: (_, __) => const MoreScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/products/:id',
          builder: (_, state) =>
              ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/products/:id/edit',
          builder: (_, state) {
            // Product is passed via extra
            final product = state.extra;
            if (product == null) return const _NotFound();
            return EditProductScreen(product: product as dynamic);
          },
        ),
        GoRoute(path: '/add-product', builder: (_, __) => const AddProductScreen()),
        GoRoute(
          path: '/stock-update',
          builder: (_, state) => StockUpdateScreen(
            type: state.uri.queryParameters['type'] ?? 'stock_in',
            productId: state.uri.queryParameters['product_id'],
          ),
        ),
        GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
        GoRoute(path: '/sync-center', builder: (_, __) => const SyncCenterScreen()),
        GoRoute(path: '/purchases', builder: (_, __) => const PurchasesScreen()),
        GoRoute(path: '/wifi-sync', builder: (_, __) => const WifiSyncScreen()),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Not found')),
      );
}
