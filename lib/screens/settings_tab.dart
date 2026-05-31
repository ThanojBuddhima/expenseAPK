import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/budget.dart';
import '../screens/auth_lock_screen.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

class _BudgetSheetResult {
  const _BudgetSheetResult({
    required this.categoryName,
    required this.amount,
    required this.year,
    required this.month,
  });

  final String categoryName;
  final double amount;
  final int year;
  final int month;
}

class _BudgetEditorSheet extends StatefulWidget {
  const _BudgetEditorSheet({this.existing});

  final Budget? existing;

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _yearController;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    _categoryController = TextEditingController(
      text: existing?.categoryName ?? '',
    );
    _yearController = TextEditingController(
      text: '${existing?.year ?? now.year}',
    );
    _month = existing?.month ?? now.month;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      return;
    }
    Navigator.of(context).pop(
      _BudgetSheetResult(
        categoryName: _categoryController.text.trim(),
        amount: amount,
        year: int.tryParse(_yearController.text.trim()) ?? DateTime.now().year,
        month: _month,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
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
            existing == null ? 'Monthly budget' : 'Edit budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Category (leave empty for overall)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Budget amount'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1}'),
                    ),
                  ),
                  onChanged: (v) => setState(() => _month = v ?? _month),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save budget'),
          ),
        ],
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.onThemeChanged,
    required this.onAccountsTap,
    required this.onCategoriesTap,
    required this.onDataChanged,
  });

  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onAccountsTap;
  final VoidCallback onCategoriesTap;
  final VoidCallback onDataChanged;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  ThemeMode _themeMode = ThemeMode.light;
  List<Budget> _budgets = [];

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
    final budgets = await DBService.instance.getAllBudgets();
    if (mounted) {
      setState(() {
        _pinEnabled = pin;
        _biometricEnabled = canBio && bio;
        _biometricAvailable = canBio;
        _themeMode = theme;
        _budgets = budgets;
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

  Future<void> _openBudgetEditor([Budget? existing]) async {
    final result = await showModalBottomSheet<_BudgetSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BudgetEditorSheet(existing: existing),
    );

    if (result == null) {
      return;
    }

    final budget = Budget(
      id: existing?.id,
      categoryName: result.categoryName,
      amount: result.amount,
      year: result.year,
      month: result.month,
    );

    if (existing == null) {
      await DBService.instance.insertBudget(budget);
    } else {
      await DBService.instance.updateBudget(budget);
    }
    widget.onDataChanged();
    await _load();
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
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Manage accounts'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onAccountsTap,
            ),
            const SizedBox(height: 12),
            _SectionTitle('Categories'),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Manage categories'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onCategoriesTap,
            ),
            const SizedBox(height: 12),
            _SectionTitle('Budget management'),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Add monthly budget'),
              trailing: const Icon(Icons.add_rounded),
              onTap: () => _openBudgetEditor(),
            ),
            ..._budgets.map(
              (budget) => Card(
                child: ListTile(
                  title: Text(
                    budget.isOverall
                        ? 'Overall • ${budget.month}/${budget.year}'
                        : '${budget.categoryName} • ${budget.month}/${budget.year}',
                  ),
                  subtitle: Text('\$${budget.amount.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (budget.id != null) {
                        await DBService.instance.deleteBudget(budget.id!);
                        widget.onDataChanged();
                        await _load();
                      }
                    },
                  ),
                  onTap: () => _openBudgetEditor(budget),
                ),
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
