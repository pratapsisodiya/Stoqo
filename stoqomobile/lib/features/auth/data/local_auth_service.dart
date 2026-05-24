import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:stoqomobile/features/auth/domain/models/branch_model.dart';
import 'package:stoqomobile/features/auth/domain/models/user_model.dart';

class LocalAuthService {
  static const _pinKey = 'local_pin_hash';
  static const _userKey = 'local_user_json';
  static const _setupKey = 'setup_complete';

  Future<bool> get isSetupComplete async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupKey) ?? false;
  }

  Future<void> setup({
    required String name,
    required String branchName,
    required String branchCode,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = const Uuid().v4();
    final branchId = const Uuid().v4();

    final user = UserModel(
      id: userId,
      name: name,
      role: 'admin',
      branchId: branchId,
    );

    await prefs.setString(_pinKey, _hashPin(pin));
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setBool(_setupKey, true);

    // Persist the branch for later reads
    await prefs.setString('local_branch_json', jsonEncode({
      'id': branchId,
      'name': branchName,
      'code': branchCode.isEmpty ? branchName.substring(0, 1).toUpperCase() : branchCode,
    }));
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userKey);
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<BranchModel?> getLocalBranch() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('local_branch_json');
    if (json == null) return null;
    final map = jsonDecode(json) as Map<String, dynamic>;
    return BranchModel(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
    );
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_userKey);
    await prefs.remove(_setupKey);
    await prefs.remove('local_branch_json');
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}
