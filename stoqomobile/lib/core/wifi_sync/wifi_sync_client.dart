import 'dart:convert';
import 'dart:io';
import 'package:stoqomobile/core/wifi_sync/wifi_sync_server.dart';

class WifiSyncResult {
  final bool success;
  final String? error;
  final int productsReceived;
  final int movementsReceived;
  final int transfersReceived;
  final int purchasesReceived;

  const WifiSyncResult({
    required this.success,
    this.error,
    this.productsReceived = 0,
    this.movementsReceived = 0,
    this.transfersReceived = 0,
    this.purchasesReceived = 0,
  });
}

class WifiSyncClient {
  /// Parses a stoqo://host:port URL
  static (String host, int port)? parseUrl(String url) {
    try {
      final clean = url.trim().replaceFirst('stoqo://', '');
      final parts = clean.split(':');
      if (parts.length != 2) return null;
      final port = int.tryParse(parts[1]);
      if (port == null) return null;
      return (parts[0], port);
    } catch (_) {
      return null;
    }
  }

  /// Verify the host is reachable
  Future<bool> ping(String host, int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req =
          await client.getUrl(Uri.parse('http://$host:$port/stoqo/ping'));
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Full bidirectional sync with step callbacks.
  /// Steps emitted: 'exporting', 'uploading', 'downloading', 'merging', 'done'
  Future<WifiSyncResult> sync(
    String host,
    int port, {
    void Function(String step)? onProgress,
  }) async {
    try {
      // Export our local data
      onProgress?.call('exporting');
      final localData = await wifiSyncServer.exportAll();

      // Push to host
      onProgress?.call('uploading');
      final pushClient = HttpClient();
      pushClient.connectionTimeout = const Duration(seconds: 30);
      final pushReq =
          await pushClient.postUrl(Uri.parse('http://$host:$port/stoqo/import'));
      pushReq.headers.set('Content-Type', 'application/json');
      pushReq.write(jsonEncode(localData));
      final pushRes = await pushReq.close();
      await pushRes.drain<void>();
      if (pushRes.statusCode != 200) {
        return const WifiSyncResult(
            success: false, error: 'Host rejected our data');
      }

      // Pull host's data
      onProgress?.call('downloading');
      final pullClient = HttpClient();
      pullClient.connectionTimeout = const Duration(seconds: 30);
      final pullReq =
          await pullClient.getUrl(Uri.parse('http://$host:$port/stoqo/export'));
      final pullRes = await pullReq.close();
      final body = await pullRes.transform(utf8.decoder).join();
      if (pullRes.statusCode != 200) {
        return WifiSyncResult(
            success: false, error: 'Failed to get host data: $body');
      }

      // Merge locally
      onProgress?.call('merging');
      final remoteData = jsonDecode(body) as Map<String, dynamic>;
      await wifiSyncServer.mergeAll(remoteData);

      onProgress?.call('done');
      return WifiSyncResult(
        success: true,
        productsReceived:
            (remoteData['products'] as List?)?.length ?? 0,
        movementsReceived:
            (remoteData['inventory_movements'] as List?)?.length ?? 0,
        transfersReceived:
            (remoteData['transfers'] as List?)?.length ?? 0,
        purchasesReceived:
            (remoteData['purchases'] as List?)?.length ?? 0,
      );
    } catch (e) {
      return WifiSyncResult(success: false, error: e.toString());
    }
  }
}
