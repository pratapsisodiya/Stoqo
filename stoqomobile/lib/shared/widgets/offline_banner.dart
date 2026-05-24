import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

/// App-wide offline indicator. Wrap the MaterialApp builder child with this.
/// Removes the top MediaQuery padding from the child so Scaffold AppBars
/// don't double-account for the status bar when the banner is visible.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final topPadding = MediaQuery.of(context).padding.top;

    if (isOnline) return child;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: MediaQuery.of(context).padding.copyWith(top: 0),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF5F6368),
            padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Offline — changes will sync when connected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
