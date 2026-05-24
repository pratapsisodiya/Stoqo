import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/features/auth/data/auth_repository.dart';
import 'package:stoqomobile/features/auth/domain/models/branch_model.dart';
import 'package:stoqomobile/features/auth/domain/models/user_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

enum AuthStatus { loading, firstRun, locked, authenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final isSetup = await _repo.isSetupComplete;
    if (!isSetup) {
      state = const AuthState(status: AuthStatus.firstRun);
      return;
    }
    final user = await _repo.getCachedUser();
    state = AuthState(status: AuthStatus.locked, user: user);
  }

  Future<void> unlock(String pin) async {
    state = state.copyWith(error: null);
    final ok = await _repo.verifyPin(pin);
    if (!ok) {
      state = state.copyWith(error: 'Incorrect PIN. Try again.');
      return;
    }
    final user = await _repo.getCachedUser();
    if (user == null) {
      state = const AuthState(status: AuthStatus.firstRun);
      return;
    }
    _ref.read(currentUserProvider.notifier).state = user;

    // Load branch
    final branch = await _repo.getLocalBranch() ??
        await _repo.getBranch(user.branchId ?? '');
    if (branch != null) {
      _ref.read(currentBranchProvider.notifier).state = branch;
      await _repo.setCurrentBranch(branch.id);

      // Ensure branch is saved in SQLite
      await _repo.saveBranch(branch);
    }

    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> completeSetup({
    required String name,
    required String branchName,
    required String branchCode,
    required String pin,
  }) async {
    await _repo.setup(
      name: name,
      branchName: branchName,
      branchCode: branchCode,
      pin: pin,
    );

    final user = await _repo.getCachedUser();
    final branch = await _repo.getLocalBranch();

    if (user == null || branch == null) {
      state = const AuthState(status: AuthStatus.firstRun,
          error: 'Setup failed. Please try again.');
      return;
    }

    // Persist branch in SQLite
    await _repo.saveBranch(branch);
    await _repo.setCurrentBranch(branch.id);

    _ref.read(currentUserProvider.notifier).state = user;
    _ref.read(currentBranchProvider.notifier).state = branch;

    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  void lock() {
    state = state.copyWith(status: AuthStatus.locked, error: null);
    _ref.read(currentUserProvider.notifier).state = null;
  }

  // Alias kept for backward compatibility
  void logout() => lock();
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepoProvider), ref);
});

// Kept for compatibility
class BranchesNotifier extends AsyncNotifier<List<BranchModel>> {
  @override
  Future<List<BranchModel>> build() async {
    return ref.watch(authRepoProvider).getCachedBranches();
  }
}

final branchesProvider =
    AsyncNotifierProvider<BranchesNotifier, List<BranchModel>>(
  BranchesNotifier.new,
);
