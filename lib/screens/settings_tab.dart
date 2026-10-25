import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/currency_option.dart';
import '../screens/auth_lock_screen.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../widgets/app_update_dialog.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.onThemeChanged,
    required this.onAccountsTap,
    required this.onCategoriesTap,
    required this.onBudgetsTap,
    required this.onCurrencyChanged,
  });

  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onAccountsTap;
  final VoidCallback onCategoriesTap;
  final VoidCallback onBudgetsTap;
  final VoidCallback onCurrencyChanged;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  ThemeMode _themeMode = ThemeMode.light;
  String _currencyCode = 'USD';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await CurrencyService.load();
    final pin = await AppPreferences.instance.pinEnabled;
    final bio = await AppPreferences.instance.biometricEnabled;
    final theme = await AppPreferences.instance.themeMode;
    final currency = await AppPreferences.instance.defaultCurrency;
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
        _currencyCode = currency;
      });
    }
  }

  Future<void> _openCurrencyPicker() async {
    var selected = _currencyCode;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Amount type',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the default currency for amounts shown in the app.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This changes display formatting only; it does not convert saved amounts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selected),
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Country / currency',
                    ),
                    items: kCurrencyOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.code,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => selected = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final option = CurrencyService.optionForCode(selected);
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.payments_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Preview'),
                          subtitle: Text(
                            CurrencyService.formatWithOption(option, 1234.56),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    await CurrencyService.setCode(selected);
    setState(() => _currencyCode = selected);
    widget.onCurrencyChanged();
  }

  CurrencyOption get _currentCurrency =>
      CurrencyService.optionForCode(_currencyCode);

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
          padding: const EdgeInsets.fromLTRB(
            16,
            AppTheme.screenTopPadding,
            16,
            140,
          ),
          children: [
            Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Device'),
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                      ],
                      selected: {_themeMode},
                      onSelectionChanged: (selected) {
                        final mode = selected.first;
                        setState(() => _themeMode = mode);
                        widget.onThemeChanged(mode);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _themeMode == ThemeMode.system
                          ? 'Matches your device light or dark setting'
                          : _themeMode == ThemeMode.dark
                              ? 'Always use dark theme'
                              : 'Always use light pastel theme',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionTitle('Security'),
            SwitchListTile(
              title: const Text('PIN lock'),
              subtitle: Text(
                _pinEnabled ? 'PIN is enabled' : 'Protect app with PIN',
              ),
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
                        if (enabled) {
                          final ok = await AuthService.instance
                              .authenticateWithBiometrics();
                          if (!ok) {
                            return;
                          }
                        }
                        await AppPreferences.instance.setBiometricEnabled(
                          enabled,
                        );
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
            _SectionTitle('App'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: const Text('Check for updates'),
                subtitle: const Text('Download latest APK from GitHub'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    checkAndPromptForUpdate(context, silentIfLatest: false),
              ),
            ),
            const SizedBox(height: 12),
            _SectionTitle('General'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.currency_exchange_rounded),
                title: const Text('Amount type'),
                subtitle: Text(_currentCurrency.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openCurrencyPicker,
              ),
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
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
