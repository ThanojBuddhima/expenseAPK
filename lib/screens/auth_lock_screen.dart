import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/pin_keypad.dart';

enum _SetupPhase { enter, confirm }

class AuthLockScreen extends StatefulWidget {
  const AuthLockScreen({
    super.key,
    this.setupMode = false,
    this.buildDashboard,
  });

  final bool setupMode;
  final Widget Function()? buildDashboard;

  @override
  State<AuthLockScreen> createState() => _AuthLockScreenState();
}

class _AuthLockScreenState extends State<AuthLockScreen> {
  String _pin = '';
  String _firstPin = '';
  _SetupPhase _setupPhase = _SetupPhase.enter;
  String? _error;
  bool _biometricAvailable = false;
  bool _shakeDots = false;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    if (!AuthService.instance.biometricsSupported) {
      return;
    }
    final enabled = await AppPreferences.instance.biometricEnabled;
    final canUse = await AuthService.instance.canUseBiometrics();
    if (!mounted) {
      return;
    }
    setState(() {
      _biometricAvailable = enabled && canUse;
    });
    if (!widget.setupMode && enabled && canUse) {
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (widget.setupMode) {
      return;
    }
    final enabled = await AppPreferences.instance.biometricEnabled;
    if (!enabled) {
      return;
    }
    final canUse = await AuthService.instance.canUseBiometrics();
    if (!canUse) {
      return;
    }
    final ok = await AuthService.instance.authenticateWithBiometrics();
    if (ok && mounted) {
      _goToDashboard();
    }
  }

  void _goToDashboard() {
    final builder = widget.buildDashboard;
    if (builder == null) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => builder()),
    );
  }

  Future<void> _rejectPin(String message) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _error = message;
      _shakeDots = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _pin = '';
        _shakeDots = false;
      });
    }
  }

  Future<void> _verifyUnlock() async {
    final valid = await AuthService.instance.verifyPin(_pin);
    if (!mounted) {
      return;
    }
    if (valid) {
      _goToDashboard();
    } else {
      await _rejectPin('Incorrect PIN');
    }
  }

  Future<void> _savePin() async {
    await AuthService.instance.setPin(_pin);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmSetupPin() async {
    if (_pin != _firstPin) {
      setState(() => _setupPhase = _SetupPhase.enter);
      await _rejectPin('PINs do not match. Try again.');
      _firstPin = '';
      return;
    }
    await _savePin();
  }

  void _onDigit(String digit) {
    if (_pin.length >= kPinLength) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = null;
    });

    if (_pin.length < kPinLength) {
      return;
    }

    if (widget.setupMode) {
      if (_setupPhase == _SetupPhase.enter) {
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (!mounted || _pin.length != kPinLength) {
            return;
          }
          setState(() {
            _firstPin = _pin;
            _pin = '';
            _setupPhase = _SetupPhase.confirm;
          });
        });
      } else {
        _confirmSetupPin();
      }
      return;
    }

    _verifyUnlock();
  }

  void _onBackspace() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  String get _title {
    if (!widget.setupMode) {
      return 'Enter PIN to unlock';
    }
    return _setupPhase == _SetupPhase.enter
        ? 'Create your PIN'
        : 'Confirm your PIN';
  }

  String get _subtitle {
    if (!widget.setupMode) {
      return 'Your data stays on this device.';
    }
    return _setupPhase == _SetupPhase.enter
        ? 'Choose a 4-digit PIN to secure the app.'
        : 'Re-enter your PIN to confirm.';
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = widget.setupMode;

    return Scaffold(
      appBar: isSetup
          ? AppBar(
              title: const Text('Set PIN'),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.lock_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              PinDotsRow(
                filledCount: _pin.length,
                shake: _shakeDots,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.expenseTint),
                ),
              ],
              const Spacer(flex: 3),
              PinKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
              ),
              if (!isSetup && _biometricAvailable) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Use biometrics'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
