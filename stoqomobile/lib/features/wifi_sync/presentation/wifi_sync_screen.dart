import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stoqomobile/core/wifi_sync/wifi_sync_client.dart';
import 'package:stoqomobile/core/wifi_sync/wifi_sync_server.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class WifiSyncScreen extends ConsumerStatefulWidget {
  const WifiSyncScreen({super.key});

  @override
  ConsumerState<WifiSyncScreen> createState() => _WifiSyncScreenState();
}

class _WifiSyncScreenState extends ConsumerState<WifiSyncScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Host state
  bool _serverRunning = false;
  String? _serverUrl;
  bool _serverStarting = false;

  // Join state
  final _urlCtrl = TextEditingController();
  bool _syncing = false;
  String? _syncError;
  String? _syncSuccess;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _urlCtrl.dispose();
    if (_serverRunning) wifiSyncServer.stop();
    super.dispose();
  }

  Future<void> _toggleServer() async {
    if (_serverRunning) {
      await wifiSyncServer.stop();
      setState(() { _serverRunning = false; _serverUrl = null; });
    } else {
      setState(() => _serverStarting = true);
      final url = await wifiSyncServer.start();
      setState(() {
        _serverStarting = false;
        _serverRunning = wifiSyncServer.isRunning;
        _serverUrl = url;
      });
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get WiFi IP. Make sure you are connected to WiFi.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _doSync() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _syncError = 'Enter the host URL');
      return;
    }

    final parsed = WifiSyncClient.parseUrl(url);
    if (parsed == null) {
      setState(() => _syncError = 'Invalid URL format. Use stoqo://192.168.x.x:7890');
      return;
    }

    setState(() { _syncing = true; _syncError = null; _syncSuccess = null; });

    final client = WifiSyncClient();
    final reachable = await client.ping(parsed.$1, parsed.$2);
    if (!reachable) {
      setState(() {
        _syncing = false;
        _syncError = 'Cannot reach host. Make sure both devices are on the same WiFi and the host is sharing.';
      });
      return;
    }

    final result = await client.sync(parsed.$1, parsed.$2);

    if (result.success) {
      // Refresh UI
      ref.invalidate(productListProvider);
      ref.invalidate(dashboardStatsProvider);

      setState(() {
        _syncing = false;
        _syncSuccess =
            'Sync complete! Received ${result.productsReceived} products and ${result.movementsReceived} movements.';
      });
    } else {
      setState(() {
        _syncing = false;
        _syncError = result.error ?? 'Sync failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Sync'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.wifi_tethering), text: 'Share (Host)'),
            Tab(icon: Icon(Icons.download_outlined), text: 'Join'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildHostTab(), _buildJoinTab()],
      ),
    );
  }

  Widget _buildHostTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        const Text(
          'Share your data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Start hosting to let another device on the same WiFi network connect and sync data with you.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 32),

        if (!_serverRunning) ...[
          ElevatedButton.icon(
            onPressed: _serverStarting ? null : _toggleServer,
            icon: _serverStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.wifi_tethering),
            label: Text(_serverStarting ? 'Starting...' : 'Start Sharing'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
          ),
        ] else ...[
          // QR code
          if (_serverUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12)
                ],
              ),
              child: Column(children: [
                QrImageView(
                  data: _serverUrl!,
                  version: QrVersions.auto,
                  size: 220,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _serverUrl!,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: _serverUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied')),
                        );
                      },
                      child: const Icon(Icons.copy_outlined,
                          size: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.inStockBg,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.inStockFg),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keep this screen open while the other device syncs.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.inStockFg),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _toggleServer,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop Sharing'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildJoinTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        const Text(
          'Connect to a host',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the URL shown on the host device, or scan their QR code with any QR scanner app.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 32),

        TextFormField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            labelText: 'Host URL',
            hintText: 'stoqo://192.168.1.x:7890',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: _syncing ? null : _doSync,
          icon: _syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync),
          label: Text(_syncing ? 'Syncing…' : 'Sync Now'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50)),
        ),

        if (_syncError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_syncError!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.danger)),
              ),
            ]),
          ),
        ],

        if (_syncSuccess != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.inStockBg,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  size: 16, color: AppColors.inStockFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_syncSuccess!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inStockFg)),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}
