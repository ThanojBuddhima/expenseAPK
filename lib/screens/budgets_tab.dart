import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/db_service.dart';
import '../widgets/bottom_add_button.dart';

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
  const _BudgetEditorSheet({
    this.existing,
    required this.existingBudgets,
  });

  final Budget? existing;
  final List<Budget> existingBudgets;

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  static const _overallValue = '';

  late final TextEditingController _amountController;
  late final TextEditingController _yearController;
  late int _month;
  late String _selectedCategory;
  List<ExpenseCategory> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    _yearController = TextEditingController(
      text: '${existing?.year ?? now.year}',
    );
    _month = existing?.month ?? now.month;
    _selectedCategory = existing?.categoryName ?? _overallValue;
    _loadCategories();
  }

  int get _year =>
      int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;

  bool _hasBudgetFor(String categoryName, int year, int month) {
    return widget.existingBudgets.any(
      (budget) {
        if (widget.existing?.id != null && budget.id == widget.existing!.id) {
          return false;
        }
        return budget.categoryName == categoryName &&
            budget.year == year &&
            budget.month == month;
      },
    );
  }

  bool get _overallTaken => _hasBudgetFor(_overallValue, _year, _month);

  List<String> get _availableCategoryNames {
    return _categories
        .map((category) => category.name)
        .where((name) => !_hasBudgetFor(name, _year, _month))
        .toList();
  }

  Future<void> _loadCategories() async {
    final items = await DBService.instance.getAllCategories();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = items;
      _loadingCategories = false;
      if (_selectedCategory.isNotEmpty &&
          !_categories.any((c) => c.name == _selectedCategory) &&
          widget.existing == null) {
        _selectedCategory = _overallTaken ? '' : _overallValue;
      }
      if (widget.existing == null &&
          _selectedCategory.isNotEmpty &&
          _hasBudgetFor(_selectedCategory, _year, _month)) {
        _selectedCategory =
            _overallTaken
                ? (_availableCategoryNames.isNotEmpty
                    ? _availableCategoryNames.first
                    : '')
                : _overallValue;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  String _budgetLabel(String categoryName) {
    return categoryName.isEmpty ? 'Overall (all categories)' : categoryName;
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      return;
    }

    final year = _year;
    final categoryName = _selectedCategory;

    if (widget.existing == null && _hasBudgetFor(categoryName, year, _month)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already set a budget for "${_budgetLabel(categoryName)}" '
            'in $_month/$year.',
          ),
        ),
      );
      return;
    }

    if (categoryName.isEmpty && _overallTaken && widget.existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already set an overall budget for $_month/$year.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _BudgetSheetResult(
        categoryName: categoryName,
        amount: amount,
        year: year,
        month: _month,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final showOverall = existing?.isOverall == true || !_overallTaken;
    final categoryItems = _availableCategoryNames;

    if (widget.existing == null &&
        !showOverall &&
        categoryItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'All budgets set',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Every category and the overall budget already have a budget '
              'for $_month/$_year.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

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
          if (_loadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (existing != null)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Category'),
              child: Text(_budgetLabel(_selectedCategory)),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('$_selectedCategory-$_month-$_year'),
              initialValue: _selectedCategory.isEmpty ||
                      (!_selectedCategory.isEmpty &&
                          widget.existing == null &&
                          _hasBudgetFor(_selectedCategory, _year, _month))
                  ? (showOverall
                      ? _overallValue
                      : (categoryItems.isNotEmpty ? categoryItems.first : null))
                  : _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: [
                if (showOverall)
                  const DropdownMenuItem(
                    value: _overallValue,
                    child: Text('Overall (all categories)'),
                  ),
                ...categoryItems.map(
                  (name) {
                    final category = _categories.firstWhere(
                      (item) => item.name == name,
                    );
                    return DropdownMenuItem(
                      value: name,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: Color(category.colorValue),
                          ),
                          const SizedBox(width: 10),
                          Text(name),
                        ],
                      ),
                    );
                  },
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedCategory = value);
              },
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
                  onChanged: (v) {
                    setState(() => _month = v ?? _month);
                    _loadCategories();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Save budget'),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetsTab extends StatefulWidget {
  const BudgetsTab({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<BudgetsTab> createState() => _BudgetsTabState();
}

class _BudgetsTabState extends State<BudgetsTab> {
  final _db = DBService.instance;
  List<Budget> _budgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _db.getAllBudgets();
    if (mounted) {
      setState(() {
        _budgets = items;
        _loading = false;
      });
    }
  }

  String _budgetLabel(Budget budget) =>
      budget.isOverall ? 'Overall budget' : budget.categoryName;

  Future<void> _openEditor([Budget? existing]) async {
    final result = await showModalBottomSheet<_BudgetSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BudgetEditorSheet(
        existing: existing,
        existingBudgets: _budgets,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    if (existing == null) {
      final duplicate = await _db.getBudgetForMonth(
        year: result.year,
        month: result.month,
        categoryName: result.categoryName,
      );
      if (duplicate != null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You already set a budget for "${_budgetLabel(duplicate)}" '
              'in ${result.month}/${result.year}.',
            ),
          ),
        );
        return;
      }
    } else {
      final conflict = await _db.getBudgetForMonth(
        year: result.year,
        month: result.month,
        categoryName: result.categoryName,
      );
      if (conflict != null && conflict.id != existing.id) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You already set a budget for "${_budgetLabel(conflict)}" '
              'in ${result.month}/${result.year}.',
            ),
          ),
        );
        return;
      }
    }

    final budget = Budget(
      id: existing?.id,
      categoryName: result.categoryName,
      amount: result.amount,
      year: result.year,
      month: result.month,
    );

    if (existing == null) {
      await _db.insertBudget(budget);
    } else {
      await _db.updateBudget(budget);
    }
    widget.onChanged();
    await _load();
  }

  Future<void> _deleteBudget(Budget budget) async {
    final label = _budgetLabel(budget);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text('Remove budget for "$label"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.expenseTint),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && budget.id != null) {
      await _db.deleteBudget(budget.id!);
      widget.onChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ManageListScaffold(
      addLabel: 'Add budget',
      onAdd: () => _openEditor(),
      padding: const EdgeInsets.fromLTRB(16, AppTheme.screenTopPadding, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Budget list',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_budgets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No budgets yet.'),
            ),
          )
        else
          ..._budgets.map(
            (budget) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(_budgetLabel(budget)),
                subtitle: Text(
                  '${budget.month}/${budget.year} • '
                  '\$${budget.amount.toStringAsFixed(2)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEditor(budget),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteBudget(budget),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
