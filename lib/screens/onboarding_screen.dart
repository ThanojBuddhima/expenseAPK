import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/currency_option.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/db_service.dart';
import '../widgets/outlined_choice_button.dart';
import '../widgets/pin_keypad.dart';

const List<String> _suggestedAccounts = ['Savings', 'Wallet', 'Bank'];

const String _kCashAccount = 'cash';

const List<Color> _accountColors = [
  AppColors.primary,
  AppColors.incomeTint,
  AppColors.expenseTint,
  AppColors.pastelPink,
  AppColors.pastelYellow,
  AppColors.pastelLavender,
  AppColors.pastelOrange,
  AppColors.darkBanner,
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.buildDashboard});

  final Widget Function() buildDashboard;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 4;

  final _pageController = PageController();
  final _accountNameController = TextEditingController();

  int _step = 0;
  String _currencyCode = 'USD';
  List<ExpenseCategory> _categories = [];
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedSuggestedAccounts = {};
  final List<_PendingAccount> _customAccounts = [];
  bool _loadingCategories = true;

  String _pin = '';
  String _firstPin = '';
  bool _pinConfirmStep = false;
  String? _pinError;
  bool _shakeDots = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final items = await DBService.instance.getAllCategories();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = items;
      _selectedCategories.addAll(items.map((c) => c.name));
      _loadingCategories = false;
    });
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        return _currencyCode.isNotEmpty;
      case 1:
        if (_selectedCategories.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one category')),
          );
          return false;
        }
        return true;
      case 2:
        return true;
      case 3:
        return false;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_validateStep()) {
      return;
    }
    if (_step < _stepCount - 1) {
      _goToStep(_step + 1);
    }
  }

  void _backStep() {
    if (_step > 0) {
      _goToStep(_step - 1);
    }
  }

  void _toggleSuggestedAccount(String name) {
    setState(() {
      if (_selectedSuggestedAccounts.contains(name)) {
        _selectedSuggestedAccounts.remove(name);
      } else {
        _selectedSuggestedAccounts.add(name);
      }
    });
  }

  void _addCustomAccount() {
    final name = _accountNameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (_customAccounts.any((a) => a.name.toLowerCase() == name.toLowerCase()) ||
        _selectedSuggestedAccounts.any((a) => a.toLowerCase() == name.toLowerCase()) ||
        name.toLowerCase() == _kCashAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account name already exists')),
      );
      return;
    }
    setState(() {
      _customAccounts.add(
        _PendingAccount(
          name: name,
          colorValue: _accountColors[
              _customAccounts.length % _accountColors.length].toARGB32(),
        ),
      );
      _accountNameController.clear();
    });
  }

  void _removeCustomAccount(_PendingAccount account) {
    setState(() => _customAccounts.remove(account));
  }

  Future<void> _rejectPin(String message) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _pinError = message;
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

  void _onPinDigit(String digit) {
    if (_pin.length >= kPinLength) {
      return;
    }
    setState(() {
      _pin += digit;
      _pinError = null;
    });

    if (_pin.length < kPinLength) {
      return;
    }

    if (!_pinConfirmStep) {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _pin.length != kPinLength) {
          return;
        }
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _pinConfirmStep = true;
        });
      });
    } else {
      _finishOnboarding();
    }
  }

  void _onPinBackspace() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = null;
    });
  }

  Future<void> _finishOnboarding() async {
    if (_pin != _firstPin) {
      setState(() {
        _pinConfirmStep = false;
        _firstPin = '';
      });
      await _rejectPin('PINs do not match. Try again.');
      return;
    }

    setState(() => _saving = true);

    try {
      await CurrencyService.setCode(_currencyCode);

      for (final category in _categories) {
        if (!_selectedCategories.contains(category.name) &&
            category.id != null) {
          await DBService.instance.deleteCategory(category.id!);
        }
      }

      var colorIndex = 0;
      for (final name in _selectedSuggestedAccounts) {
        await DBService.instance.insertAccount(
          Account(
            name: name,
            balance: 0,
            colorValue: _accountColors[
                    colorIndex++ % _accountColors.length]
                .toARGB32(),
          ),
        );
      }
      for (final account in _customAccounts) {
        await DBService.instance.insertAccount(
          Account(
            name: account.name,
            balance: 0,
            colorValue: account.colorValue,
          ),
        );
      }

      await AuthService.instance.setPin(_pin);
      await AppPreferences.instance.setOnboardingComplete(true);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.buildDashboard()),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step ${_step + 1} of $_stepCount',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (_step + 1) / _stepCount,
                    backgroundColor: palette.border,
                    color: AppColors.primary,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _step = index),
                children: [
                  _CurrencyStep(
                    currencyCode: _currencyCode,
                    onChanged: (code) => setState(() => _currencyCode = code),
                  ),
                  _CategoryStep(
                    loading: _loadingCategories,
                    categories: _categories,
                    selected: _selectedCategories,
                    onToggle: (name) {
                      setState(() {
                        if (_selectedCategories.contains(name)) {
                          _selectedCategories.remove(name);
                        } else {
                          _selectedCategories.add(name);
                        }
                      });
                    },
                  ),
                  _AccountsStep(
                    selectedSuggested: _selectedSuggestedAccounts,
                    customAccounts: _customAccounts,
                    nameController: _accountNameController,
                    onToggleSuggested: _toggleSuggestedAccount,
                    onAddCustom: _addCustomAccount,
                    onRemoveCustom: _removeCustomAccount,
                  ),
                  _PinStep(
                    confirmStep: _pinConfirmStep,
                    pinLength: _pin.length,
                    error: _pinError,
                    shake: _shakeDots,
                    saving: _saving,
                    onDigit: _onPinDigit,
                    onBackspace: _onPinBackspace,
                  ),
                ],
              ),
            ),
            if (_step < 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _backStep,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                            side: BorderSide(color: palette.border),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _step > 0 ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingAccount {
  const _PendingAccount({required this.name, required this.colorValue});

  final String name;
  final int colorValue;
}

class _CurrencyStep extends StatelessWidget {
  const _CurrencyStep({
    required this.currencyCode,
    required this.onChanged,
  });

  final String currencyCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final option = kCurrencyOptions.firstWhere(
      (item) => item.code == currencyCode,
      orElse: () => kCurrencyOptions.first,
    );
    final preview = _formatPreview(option, 1234.56);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Choose your currency',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick the default amount type for your country. You can change this later in settings.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          key: ValueKey(currencyCode),
          initialValue: currencyCode,
          decoration: const InputDecoration(labelText: 'Country / currency'),
          items: kCurrencyOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option.code,
                  child: Text(option.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
            title: const Text('Preview'),
            subtitle: Text(
              preview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatPreview(CurrencyOption option, double value) {
  final s = value.toStringAsFixed(2);
  final parts = s.split('.');
  final integer = parts[0];
  final fraction = parts.length > 1 ? parts[1] : '00';
  final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
  final withCommas = integer.replaceAllMapped(reg, (m) => ',${m.group(0)}');
  if (option.code == 'INR' || option.code == 'LKR') {
    return '${option.symbol} $withCommas.$fraction';
  }
  return '${option.symbol}$withCommas.$fraction';
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({
    required this.loading,
    required this.categories,
    required this.selected,
    required this.onToggle,
  });

  final bool loading;
  final List<ExpenseCategory> categories;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Select categories',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the categories you want to track. You can add more later.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((category) {
            final isSelected = selected.contains(category.name);
            return OutlinedChoiceButton(
              label: category.name,
              color: Color(category.colorValue),
              isSelected: isSelected,
              compact: true,
              onTap: () => onToggle(category.name),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AccountsStep extends StatelessWidget {
  const _AccountsStep({
    required this.selectedSuggested,
    required this.customAccounts,
    required this.nameController,
    required this.onToggleSuggested,
    required this.onAddCustom,
    required this.onRemoveCustom,
  });

  final Set<String> selectedSuggested;
  final List<_PendingAccount> customAccounts;
  final TextEditingController nameController;
  final ValueChanged<String> onToggleSuggested;
  final VoidCallback onAddCustom;
  final ValueChanged<_PendingAccount> onRemoveCustom;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Set up accounts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cash is always available. Add optional accounts to track balances.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.cashTint.withValues(alpha: 0.14),
              child: const Icon(Icons.payments_outlined, color: AppColors.cashTint),
            ),
            title: const Text('Cash'),
            subtitle: const Text('Always included'),
            trailing: Icon(Icons.check_circle, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 12),
        Text('Suggested accounts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ..._suggestedAccounts.map(
          (name) {
            final isSelected = selectedSuggested.contains(name);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: palette.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : palette.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (_) => onToggleSuggested(name),
                  title: Text(name),
                  secondary: const Icon(Icons.account_balance_wallet_outlined),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Add custom account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Account name',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAddCustom(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onAddCustom,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        if (customAccounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...customAccounts.map(
            (account) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Color(account.colorValue).withValues(alpha: 0.14),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(account.colorValue),
                  ),
                ),
                title: Text(account.name),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onRemoveCustom(account),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PinStep extends StatelessWidget {
  const _PinStep({
    required this.confirmStep,
    required this.pinLength,
    required this.error,
    required this.shake,
    required this.saving,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool confirmStep;
  final int pinLength;
  final String? error;
  final bool shake;
  final bool saving;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: [
          Icon(
            Icons.lock_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            confirmStep ? 'Confirm your PIN' : 'Create your PIN',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            confirmStep
                ? 'Re-enter your 4-digit PIN to finish setup.'
                : 'Choose a 4-digit PIN to secure the app.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          PinDotsRow(filledCount: pinLength, shake: shake),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.expenseTint),
            ),
          ],
          if (saving) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
          const Spacer(),
          PinKeypad(onDigit: onDigit, onBackspace: onBackspace),
        ],
      ),
    );
  }
}
