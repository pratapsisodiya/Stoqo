import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

/// Legacy screen — router now redirects to /setup or /unlock directly.
/// Kept as a no-op redirect to avoid dead import errors.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authNotifierProvider).status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      switch (status) {
        case AuthStatus.firstRun:
          context.go('/setup');
        case AuthStatus.locked:
          context.go('/unlock');
        case AuthStatus.authenticated:
          context.go('/');
        case AuthStatus.loading:
          break;
      }
    });
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
