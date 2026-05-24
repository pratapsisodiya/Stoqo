import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/features/auth/data/auth_repository.dart';
import 'package:stoqomobile/features/auth/domain/models/branch_model.dart';
import 'package:stoqomobile/features/auth/domain/models/user_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({this.status = AuthStatus.unknown, this.user, this.error});
  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user, error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final user = await _repo.getCachedUser();
    if (user != null) {
      _ref.read(currentUserProvider.notifier).state = user;
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String login, String password) async {
    state = state.copyWith(status: AuthStatus.unknown, error: null);
    try {
      final user = await _repo.login(login, password);
      _ref.read(currentUserProvider.notifier).state = user;
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _ref.read(currentUserProvider.notifier).state = null;
    _ref.read(currentBranchProvider.notifier).state = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _parseError(Object e) {
    return 'Login failed. Check your credentials.';
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepoProvider), ref);
});

// Branches
class BranchesNotifier extends AsyncNotifier<List<BranchModel>> {
  @override
  Future<List<BranchModel>> build() async {
    final repo = ref.watch(authRepoProvider);
    final cached = await repo.getCachedBranches();
    if (cached.isNotEmpty) return cached;
    try {
      final branches = await repo.fetchBranches();
      for (final b in branches) {
        await repo.saveBranch(b);
      }
      return branches;
    } catch (_) {
      return cached;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final branchesProvider = AsyncNotifierProvider<BranchesNotifier, List<BranchModel>>(
  BranchesNotifier.new,
);
