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
  const _BudgetEditorSheet({this.existing});

  final Budget? existing;

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

  Future<void> _loadCategories() async {
    final items = await DBService.instance.getAllCategories();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = items;
      _loadingCategories = false;
      if (_selectedCategory.isNotEmpty &&
          !items.any((c) => c.name == _selectedCategory)) {
        _selectedCategory = _overallValue;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
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
        categoryName: _selectedCategory,
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
          if (_loadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedCategory),
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: [
                const DropdownMenuItem(
                  value: _overallValue,
                  child: Text('Overall (all categories)'),
                ),
                ..._categories.map(
                  (category) => DropdownMenuItem(
                    value: category.name,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: Color(category.colorValue),
                        ),
                        const SizedBox(width: 10),
                        Text(category.name),
                      ],
                    ),
                  ),
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

  Future<void> _openEditor([Budget? existing]) async {
    final result = await showModalBottomSheet<_BudgetSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BudgetEditorSheet(existing: existing),
    );

    if (result == null || !mounted) {
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
      await _db.insertBudget(budget);
    } else {
      await _db.updateBudget(budget);
    }
    widget.onChanged();
    await _load();
  }

  Future<void> _deleteBudget(Budget budget) async {
    final label = budget.isOverall ? 'Overall budget' : budget.categoryName;
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
                title: Text(
                  budget.isOverall ? 'Overall budget' : budget.categoryName,
                ),
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
