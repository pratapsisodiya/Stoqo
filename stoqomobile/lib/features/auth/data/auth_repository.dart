import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/constants/app_constants.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/network/api_client.dart';
import 'package:stoqomobile/features/auth/domain/models/branch_model.dart';
import 'package:stoqomobile/features/auth/domain/models/user_model.dart';

class AuthRepository {
  final Dio _dio = ApiClient.instance.dio;
  final _storage = const FlutterSecureStorage();

  Future<UserModel> login(String login, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'login': login,
      'password': password,
    });
    final body = response.data as Map<String, dynamic>;
    await _storage.write(
        key: AppConstants.tokenKey, value: body['access_token'] as String);
    await _storage.write(
        key: AppConstants.refreshTokenKey, value: body['refresh_token'] as String);
    return fetchMe();
  }

  Future<UserModel> fetchMe() async {
    final response = await _dio.get('/auth/me');
    final user = UserModel.fromJson(response.data as Map<String, dynamic>);
    await _storage.write(
        key: AppConstants.currentUserKey, value: jsonEncode(user.toJson()));
    return user;
  }

  Future<UserModel?> getCachedUser() async {
    final json = await _storage.read(key: AppConstants.currentUserKey);
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<bool> get isLoggedIn async =>
      (await _storage.read(key: AppConstants.tokenKey)) != null;

  Future<void> logout() async => _storage.deleteAll();

  Future<List<BranchModel>> fetchBranches() async {
    try {
      final response = await _dio.get('/branches');
      final branches = (response.data as List)
          .map((j) => BranchModel.fromJson(j as Map<String, dynamic>))
          .toList();
      final db = await AppDatabase.instance;
      for (final b in branches) {
        await db.insert('branches', b.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return branches;
    } catch (_) {
      return getCachedBranches();
    }
  }

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

  Future<void> setCurrentBranch(String branchId) async =>
      _storage.write(key: AppConstants.currentBranchKey, value: branchId);

  Future<String?> getCurrentBranchId() async =>
      _storage.read(key: AppConstants.currentBranchKey);
}
