import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stoqomobile/core/database/app_database.dart';

const _kPort = 7890;

class WifiSyncServer {
  HttpServer? _server;
  String? _localIp;

  String? get localIp => _localIp;
  int get port => _kPort;
  bool get isRunning => _server != null;

  Future<String?> start() async {
    if (_server != null) return _syncUrl();

    _localIp = await NetworkInfo().getWifiIP();
    if (_localIp == null) return null;

    final router = Router()
      ..get('/stoqo/export', _handleExport)
      ..post('/stoqo/import', _handleImport)
      ..get('/stoqo/ping', _handlePing);

    final handler = const Pipeline()
        .addMiddleware(_cors())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _kPort);
    return _syncUrl();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  String? _syncUrl() =>
      _localIp != null ? 'stoqo://$_localIp:$_kPort' : null;

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<Response> _handlePing(Request req) =>
      Future.value(Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'Content-Type': 'application/json'}));

  Future<Response> _handleExport(Request req) async {
    try {
      final data = await exportAll();
      return Response.ok(jsonEncode(data),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _handleImport(Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      await mergeAll(data);
      return Response.ok(jsonEncode({'status': 'merged'}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}));
    }
  }

  // ── Export all local data ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportAll() async {
    final db = await AppDatabase.instance;
    return {
      'products': await db.query('products'),
      'inventory_movements': await db.query('inventory_movements'),
      'branches': await db.query('branches'),
      'alerts': await db.query('alerts'),
      'transfers': await db.query('transfers'),
      'transfer_items': await db.query('transfer_items'),
      'purchases': await db.query('purchases'),
      'purchase_items': await db.query('purchase_items'),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  // ── Merge incoming data (last-write-wins by updated_at) ───────────────────

  Future<void> mergeAll(Map<String, dynamic> data) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await _mergeTable(txn, 'products', data, updatedAtField: 'updated_at');
      await _mergeTable(txn, 'branches', data);
      await _mergeTable(txn, 'alerts', data);
      await _mergeTable(txn, 'transfers', data);
      await _mergeTable(txn, 'transfer_items', data);
      await _mergeTable(txn, 'purchases', data);
      await _mergeTable(txn, 'purchase_items', data);
      await _appendTable(txn, 'inventory_movements', data);
    });
  }

  Future<void> _mergeTable(
    Transaction txn,
    String table,
    Map<String, dynamic> data, {
    String? updatedAtField,
  }) async {
    final rows = data[table] as List? ?? [];
    for (final rowRaw in rows) {
      final row = Map<String, dynamic>.from(rowRaw as Map);
      if (updatedAtField != null && row[updatedAtField] != null) {
        // Check existing row
        final existing = await txn.query(table,
            where: 'id = ?', whereArgs: [row['id']]);
        if (existing.isNotEmpty) {
          final existingTs = existing.first[updatedAtField] as String?;
          final incomingTs = row[updatedAtField] as String?;
          if (existingTs != null &&
              incomingTs != null &&
              incomingTs.compareTo(existingTs) <= 0) {
            continue; // Local is newer or same — skip
          }
        }
      }
      await txn.insert(table, row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _appendTable(
      Transaction txn, String table, Map<String, dynamic> data) async {
    final rows = data[table] as List? ?? [];
    for (final rowRaw in rows) {
      final row = Map<String, dynamic>.from(rowRaw as Map);
      await txn.insert(table, row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Middleware _cors() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        });
      };
    };
  }
}

final wifiSyncServer = WifiSyncServer();
