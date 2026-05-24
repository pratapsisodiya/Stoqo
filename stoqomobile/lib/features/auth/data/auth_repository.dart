import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/features/auth/data/local_auth_service.dart';
import 'package:stoqomobile/features/auth/domain/models/branch_model.dart';
import 'package:stoqomobile/features/auth/domain/models/user_model.dart';

class AuthRepository {
  final _localAuth = LocalAuthService();

  Future<bool> get isSetupComplete => _localAuth.isSetupComplete;

  Future<UserModel?> getCachedUser() => _localAuth.getUser();

  Future<bool> verifyPin(String pin) => _localAuth.verifyPin(pin);

  Future<void> setup({
    required String name,
    required String branchName,
    required String branchCode,
    required String pin,
  }) =>
      _localAuth.setup(
          name: name, branchName: branchName, branchCode: branchCode, pin: pin);

  Future<BranchModel?> getLocalBranch() => _localAuth.getLocalBranch();

  Future<void> lock() async {}

  Future<void> reset() => _localAuth.reset();

  // ── Branch helpers ─────────────────────────────────────────────────────────

  Future<List<BranchModel>> getCachedBranches() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('branches');
    return rows.map(BranchModel.fromDb).toList();
  }

  Future<void> saveBranch(BranchModel branch) async {
    final db = await AppDatabase.instance;
    await db.insert('branches', branch.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<BranchModel?> getBranch(String id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('branches', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return BranchModel.fromDb(rows.first);
  }

  Future<void> setCurrentBranch(String branchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_branch_id', branchId);
  }

  Future<String?> getCurrentBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_branch_id');
  }
}
