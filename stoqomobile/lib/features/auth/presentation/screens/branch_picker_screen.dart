import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stoqomobile/core/sync/connectivity_service.dart';
import 'package:stoqomobile/features/auth/data/initial_sync_service.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/features/auth/domain/models/branch_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class BranchPickerScreen extends ConsumerWidget {
  const BranchPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Branch'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: _BranchList(userBranchId: user?.branchId),
    );
  }
}

class _BranchList extends ConsumerWidget {
  final String? userBranchId;
  const _BranchList({this.userBranchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(authRepoProvider);
    return FutureBuilder<List<BranchModel>>(
      future: repo.getCachedBranches().then((cached) async {
        if (cached.isNotEmpty) return cached;
        if (userBranchId != null) {
          return [BranchModel(id: userBranchId!, name: 'My Branch', code: 'MY')];
        }
        return cached;
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final branches = snapshot.data ?? [];

        if (branches.isEmpty && userBranchId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _selectBranch(context, ref,
                BranchModel(id: userBranchId!, name: 'My Branch', code: 'MY'));
          });
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: branches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final branch = branches[i];
            return Card(
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(branch.code.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                title: Text(branch.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(branch.address ?? branch.code),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectBranch(context, ref, branch),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectBranch(
      BuildContext context, WidgetRef ref, BranchModel branch) async {
    ref.read(currentBranchProvider.notifier).state = branch;
    ref.read(authRepoProvider).setCurrentBranch(branch.id);

    // Kick off full initial sync in background if online — don't block navigation
    final online = await ConnectivityService.instance.isOnline;
    if (online) {
      const InitialSyncService().syncBranch(branch.id, cursor: branch.syncCursor);
    }

    if (context.mounted) context.go('/');
  }
}
