import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';

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
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    if (!widget.setupMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _checkBiometrics() async {
    if (!AuthService.instance.biometricsSupported) {
      return;
    }
    final enabled = await AppPreferences.instance.biometricEnabled;
    final canUse = await AuthService.instance.canUseBiometrics();
    if (mounted) {
      setState(() {
        _biometricAvailable = enabled && canUse;
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (!_biometricAvailable) {
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

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }

    if (widget.setupMode) {
      final confirm = _confirmController.text.trim();
      if (pin != confirm) {
        setState(() => _error = 'PINs do not match');
        return;
      }
      await AuthService.instance.setPin(pin);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    final valid = await AuthService.instance.verifyPin(pin);
    if (!mounted) {
      return;
    }
    if (valid) {
      _goToDashboard();
    } else {
      setState(() => _error = 'Incorrect PIN');
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = widget.setupMode;
    return Scaffold(
      appBar: isSetup ? AppBar(title: const Text('Set PIN')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.lock_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isSetup ? 'Create your PIN' : 'Enter PIN to unlock',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isSetup
                    ? 'Use at least 4 digits to secure the app.'
                    : 'Your data stays on this device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                ),
              ),
              if (isSetup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    counterText: '',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.expenseTint),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isSetup ? 'Save PIN' : 'Unlock'),
              ),
              if (!isSetup && _biometricAvailable) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Use biometrics'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
