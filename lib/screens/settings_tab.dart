import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/auth_lock_screen.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.onThemeChanged,
    required this.onAccountsTap,
    required this.onCategoriesTap,
    required this.onBudgetsTap,
  });

  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onAccountsTap;
  final VoidCallback onCategoriesTap;
  final VoidCallback onBudgetsTap;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await AppPreferences.instance.pinEnabled;
    final bio = await AppPreferences.instance.biometricEnabled;
    final theme = await AppPreferences.instance.themeMode;
    final canBio = await AuthService.instance.canUseBiometrics();
    if (!canBio && bio) {
      await AppPreferences.instance.setBiometricEnabled(false);
    }
    if (mounted) {
      setState(() {
        _pinEnabled = pin;
        _biometricEnabled = canBio && bio;
        _biometricAvailable = canBio;
        _themeMode = theme;
      });
    }
  }

  Future<void> _setupPin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AuthLockScreen(setupMode: true),
      ),
    );
    if (ok == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, AppTheme.screenTopPadding, 16, 140),
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Appearance'),
            SwitchListTile(
              title: const Text('Dark mode'),
              subtitle: const Text(
                'Off = light pastel theme (recommended)',
              ),
              value: _themeMode == ThemeMode.dark,
              onChanged: (enabled) {
                final mode = enabled ? ThemeMode.dark : ThemeMode.light;
                setState(() => _themeMode = mode);
                widget.onThemeChanged(mode);
              },
            ),
            const SizedBox(height: 12),
            _SectionTitle('Security'),
            SwitchListTile(
              title: const Text('PIN lock'),
              subtitle: Text(_pinEnabled ? 'PIN is enabled' : 'Protect app with PIN'),
              value: _pinEnabled,
              onChanged: (enabled) async {
                if (enabled) {
                  await _setupPin();
                } else {
                  await AppPreferences.instance.clearPin();
                  await _load();
                }
              },
            ),
            if (_biometricAvailable)
              SwitchListTile(
                title: const Text('Biometric unlock'),
                subtitle: const Text('Fingerprint / Face ID'),
                value: _biometricEnabled,
                onChanged: _pinEnabled
                    ? (enabled) async {
                        await AppPreferences.instance.setBiometricEnabled(enabled);
                        await _load();
                      }
                    : null,
              ),
            ListTile(
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Change PIN'),
              enabled: _pinEnabled,
              onTap: _pinEnabled ? _setupPin : null,
            ),
            const SizedBox(height: 12),
            _SectionTitle('Accounts'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Manage accounts'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onAccountsTap,
              ),
            ),
            const SizedBox(height: 12),
            _SectionTitle('Categories'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Manage categories'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onCategoriesTap,
              ),
            ),
            const SizedBox(height: 12),
            _SectionTitle('Budgets'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: const Text('Manage budgets'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onBudgetsTap,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cloud backup is not included in this build (per project scope). '
              'All data is stored locally on your device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
