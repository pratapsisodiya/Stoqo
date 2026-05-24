import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stoqomobile/core/wifi_sync/wifi_sync_client.dart';
import 'package:stoqomobile/core/wifi_sync/wifi_sync_server.dart';
import 'package:stoqomobile/features/inventory/domain/inventory_notifier.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

// ── Step model ───────────────────────────────────────────────────────────────

enum _Step { connecting, exporting, uploading, downloading, merging, done }

const _stepLabels = {
  _Step.connecting: 'Connecting to host',
  _Step.exporting: 'Preparing local data',
  _Step.uploading: 'Uploading to host',
  _Step.downloading: 'Downloading from host',
  _Step.merging: 'Merging & saving',
  _Step.done: 'Done',
};

// ── Main screen ──────────────────────────────────────────────────────────────

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
  DateTime? _serverStartTime;

  // Join state
  final _urlCtrl = TextEditingController();
  bool _syncing = false;
  _Step? _currentStep;
  String? _syncError;
  WifiSyncResult? _syncResult;

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

  // ── Host actions ────────────────────────────────────────────────────────────

  Future<void> _toggleServer() async {
    if (_serverRunning) {
      await wifiSyncServer.stop();
      setState(() {
        _serverRunning = false;
        _serverUrl = null;
        _serverStartTime = null;
      });
    } else {
      setState(() => _serverStarting = true);
      final url = await wifiSyncServer.start();
      setState(() {
        _serverStarting = false;
        _serverRunning = wifiSyncServer.isRunning;
        _serverUrl = url;
        _serverStartTime = wifiSyncServer.isRunning ? DateTime.now() : null;
      });
      if (url == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not get WiFi IP. Make sure you are on a WiFi network.'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  // ── Join actions ────────────────────────────────────────────────────────────

  Future<void> _scanQr() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (ctx) => _QrScanSheet(
        onScanned: (url) {
          _urlCtrl.text = url;
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _doSync() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _syncError = 'Enter or scan the host URL');
      return;
    }
    final parsed = WifiSyncClient.parseUrl(url);
    if (parsed == null) {
      setState(() =>
          _syncError = 'Invalid URL. Format: stoqo://192.168.x.x:7890');
      return;
    }

    setState(() {
      _syncing = true;
      _syncError = null;
      _syncResult = null;
      _currentStep = _Step.connecting;
    });

    final client = WifiSyncClient();
    final reachable = await client.ping(parsed.$1, parsed.$2);
    if (!reachable) {
      setState(() {
        _syncing = false;
        _currentStep = null;
        _syncError =
            'Cannot reach host. Make sure both devices are on the same WiFi and the host is sharing.';
      });
      return;
    }

    final result = await client.sync(
      parsed.$1,
      parsed.$2,
      onProgress: (step) {
        if (!mounted) return;
        setState(() {
          _currentStep = switch (step) {
            'exporting' => _Step.exporting,
            'uploading' => _Step.uploading,
            'downloading' => _Step.downloading,
            'merging' => _Step.merging,
            'done' => _Step.done,
            _ => _currentStep,
          };
        });
      },
    );

    if (result.success) {
      ref.invalidate(productListProvider);
      ref.invalidate(dashboardStatsProvider);
    }

    setState(() {
      _syncing = false;
      if (result.success) {
        _syncResult = result;
        _currentStep = _Step.done;
      } else {
        _currentStep = null;
        _syncError = result.error ?? 'Sync failed';
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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

  // ── Host tab ────────────────────────────────────────────────────────────────

  Widget _buildHostTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 4),
        const Text('Share your data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Start hosting to let another device on the same WiFi connect and sync inventory data.',
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
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
            label: Text(_serverStarting ? 'Starting…' : 'Start Sharing'),
            style:
                ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ] else ...[
          // Live status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.inStockBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.inStockFg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Live${_serverStartTime != null ? ' · ${_elapsed(_serverStartTime!)}' : ''}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inStockFg),
              ),
              const Spacer(),
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (_, __) => Text(
                  _serverStartTime != null
                      ? _elapsed(_serverStartTime!)
                      : '',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inStockFg),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          if (_serverUrl != null) ...[
            // QR code card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07), blurRadius: 12)
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
                    Flexible(
                      child: Text(
                        _serverUrl!,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _serverUrl!));
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.lowStockFg),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keep this screen open while the other device syncs.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.lowStockFg),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],

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
    );
  }

  // ── Join tab ────────────────────────────────────────────────────────────────

  Widget _buildJoinTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 4),
        const Text('Connect to a host',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Scan the QR code shown on the host device, or type the URL manually.',
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),

        // URL input + scan button
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _urlCtrl,
              enabled: !_syncing,
              decoration: const InputDecoration(
                labelText: 'Host URL',
                hintText: 'stoqo://192.168.1.x:7890',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: _syncing ? null : _scanQr,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 20),
                  SizedBox(height: 2),
                  Text('Scan', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: _syncing ? null : _doSync,
          icon: const Icon(Icons.sync),
          label: const Text('Sync Now'),
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),

        // Step progress
        if (_syncing || (_syncResult != null && _currentStep == _Step.done)) ...[
          const SizedBox(height: 24),
          _buildStepProgress(),
        ],

        // Error
        if (_syncError != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_syncError!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.danger)),
              ),
            ]),
          ),
        ],

        // Success result card
        if (_syncResult != null && _currentStep == _Step.done) ...[
          const SizedBox(height: 20),
          _buildResultCard(_syncResult!),
        ],
      ],
    );
  }

  Widget _buildStepProgress() {
    final steps = _Step.values.where((s) => s != _Step.done).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final step = entry.value;
          final stepIdx = steps.indexOf(step);
          final currentIdx = _currentStep != null && _currentStep != _Step.done
              ? steps.indexOf(_currentStep!)
              : steps.length;
          final isDone = stepIdx < currentIdx ||
              (_currentStep == _Step.done);
          final isCurrent =
              _currentStep != _Step.done && stepIdx == currentIdx;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(
                width: 24,
                height: 24,
                child: isDone
                    ? const Icon(Icons.check_circle,
                        color: AppColors.secondary, size: 20)
                    : isCurrent
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary))
                        : Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.border,
                              shape: BoxShape.circle,
                            ),
                          ),
              ),
              const SizedBox(width: 12),
              Text(
                _stepLabels[step]!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.normal,
                  color: isDone
                      ? AppColors.secondary
                      : isCurrent
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultCard(WifiSyncResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inStockBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
            SizedBox(width: 8),
            Text('Sync complete',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.secondary)),
          ]),
          const SizedBox(height: 12),
          _ResultRow(
              Icons.inventory_2_outlined, 'Products', result.productsReceived),
          _ResultRow(Icons.swap_vert, 'Movements', result.movementsReceived),
          if (result.transfersReceived > 0)
            _ResultRow(
                Icons.swap_horiz, 'Transfers', result.transfersReceived),
          if (result.purchasesReceived > 0)
            _ResultRow(Icons.receipt_long_outlined, 'Purchases',
                result.purchasesReceived),
        ],
      ),
    );
  }

  String _elapsed(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
  }
}

// ── QR scan bottom sheet ────────────────────────────────────────────────────

class _QrScanSheet extends StatefulWidget {
  final void Function(String url) onScanned;
  const _QrScanSheet({required this.onScanned});

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Point camera at the QR code on the host device',
            style: TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: MobileScanner(
              onDetect: (capture) {
                if (_detected) return;
                for (final barcode in capture.barcodes) {
                  final val = barcode.rawValue ?? '';
                  if (val.startsWith('stoqo://')) {
                    _detected = true;
                    widget.onScanned(val);
                    break;
                  }
                }
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Result row helper ────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _ResultRow(this.icon, this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.inStockFg),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inStockFg))),
        Text('$count records',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.inStockFg)),
      ]),
    );
  }
}
