import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/features/auth/domain/auth_notifier.dart';
import 'package:stoqomobile/shared/theme/app_colors.dart';

class FirstRunScreen extends ConsumerStatefulWidget {
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  final _pageCtrl = PageController();

  // Page 1
  final _nameCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _form1Key = GlobalKey<FormState>();

  // Page 2
  String _pin = '';
  String _confirmPin = '';
  bool _confirmMode = false;
  String? _pinError;

  bool _loading = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  void _goPage2() {
    if (!_form1Key.currentState!.validate()) return;
    _pageCtrl.animateToPage(1,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _onPinKey(String digit) {
    setState(() {
      _pinError = null;
      if (!_confirmMode) {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) {
            // Move to confirm
            _confirmMode = true;
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) {
            _submit();
          }
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _pinError = null;
      if (_confirmMode) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _confirmMode = false;
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_pin != _confirmPin) {
      setState(() {
        _pinError = 'PINs do not match. Start over.';
        _pin = '';
        _confirmPin = '';
        _confirmMode = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).completeSetup(
            name: _nameCtrl.text.trim(),
            branchName: _branchCtrl.text.trim(),
            branchCode: _branchCtrl.text.trim().substring(0, 1).toUpperCase(),
            pin: _pin,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _pinError = 'Setup failed: $e';
          _pin = '';
          _confirmPin = '';
          _confirmMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildPage1(),
            _buildPage2(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 24),
          const Text('Welcome to Stoqo',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Set up your business profile to get started. Everything stays on your device — no internet required.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 40),
          Form(
            key: _form1Key,
            child: Column(children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _branchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business / Branch name',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _goPage2,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Continue'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    final current = _confirmMode ? _confirmPin : _pin;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.lock_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            _confirmMode ? 'Confirm your PIN' : 'Set a PIN',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _confirmMode
                ? 'Enter the PIN again to confirm'
                : 'Choose a 4-digit PIN to secure the app',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < current.length;
              return Container(
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

          if (_pinError != null) ...[
            const SizedBox(height: 16),
            Text(_pinError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
                textAlign: TextAlign.center),
          ],

          const SizedBox(height: 40),

          if (_loading)
            const CircularProgressIndicator()
          else
            _Numpad(onKey: _onPinKey, onBackspace: _onBackspace),

          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _pin = '';
                _confirmPin = '';
                _confirmMode = false;
                _pinError = null;
              });
              _pageCtrl.animateToPage(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut);
            },
            child: const Text('Back'),
          ),
        ],
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
