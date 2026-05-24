import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  String _pin = '';
  bool _loading = false;

  void _onKey(String digit) {
    if (_pin.length >= 4 || _loading) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) _verify();
  }

  void _onBackspace() {
    if (_pin.isEmpty || _loading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    await ref.read(authNotifierProvider.notifier).unlock(_pin);
    if (mounted) {
      setState(() {
        _loading = false;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return PopScope(
      canPop: false,
      child: Scaffold(

        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back${user != null ? ', ${user.name.split(' ').first}' : ''}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your PIN to continue',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 40),

                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? AppColors.primary : AppColors.border,
                        ),
                      );
                    }),
                  ),

                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      authState.error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 40),

                  if (_loading)
                    const CircularProgressIndicator()
                  else
                    _Numpad(onKey: _onKey, onBackspace: _onBackspace),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onBackspace;
  const _Numpad({required this.onKey, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];
    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 80, height: 64);
            if (k == '<') {
              return _NumKey(
                onTap: onBackspace,
                child: const Icon(Icons.backspace_outlined, size: 20),
              );
            }
            return _NumKey(
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w600)),
              onTap: () => onKey(k),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _NumKey({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 64,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
