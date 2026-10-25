import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/category.dart';
import '../services/db_service.dart';
import '../widgets/bottom_add_button.dart';

class _CategorySheetResult {
  const _CategorySheetResult({required this.name, required this.colorValue});

  final String name;
  final int colorValue;
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({this.category, required this.isIncome});

  final ExpenseCategory? category;
  final bool isIncome;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  static const _palette = AppColors.chartPalette;

  late final TextEditingController _nameController;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.colorValue ?? _palette.first.toARGB32();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_CategorySheetResult(name: name, colorValue: _selectedColor));
  }

  @override
  Widget build(BuildContext context) {
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
            widget.category == null
                ? 'New ${widget.isIncome ? 'income ' : ''}category'
                : 'Edit ${widget.isIncome ? 'income ' : ''}category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _palette.map((color) {
              final colorValue = color.toARGB32();
              final selected = _selectedColor == colorValue;
              final palette = context.palette;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorValue),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? color : palette.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.circle, size: 20, color: color),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final _db = DBService.instance;
  List<ExpenseCategory> _categories = [];
  List<ExpenseCategory> _incomeCategories = [];
  bool _loading = true;
  bool _showIncome = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _db.getAllCategories(),
      _db.getAllIncomeCategories(),
    ]);
    if (mounted) {
      setState(() {
        _categories = results[0];
        _incomeCategories = results[1];
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({
    ExpenseCategory? category,
    required bool isIncome,
  }) async {
    final result = await showModalBottomSheet<_CategorySheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _CategoryEditorSheet(category: category, isIncome: isIncome),
    );

    if (result == null || !mounted) {
      return;
    }

    final existingCategories = isIncome ? _incomeCategories : _categories;
    final duplicate = existingCategories.any(
      (item) =>
          item.id != category?.id &&
          item.name.trim().toLowerCase() == result.name.toLowerCase(),
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A category with this name already exists')),
      );
      return;
    }

    if (category == null) {
      final newCategory = ExpenseCategory(
        name: result.name,
        colorValue: result.colorValue,
      );
      if (isIncome) {
        await _db.insertIncomeCategory(newCategory);
      } else {
        await _db.insertCategory(newCategory);
      }
    } else {
      final updated = ExpenseCategory(
        id: category.id,
        name: result.name,
        colorValue: result.colorValue,
      );
      if (isIncome) {
        await _db.updateIncomeCategory(updated);
      } else {
        await _db.updateCategory(updated);
      }
    }
    widget.onChanged();
    await _load();
  }

  Future<void> _deleteCategory(
    ExpenseCategory category, {
    required bool isIncome,
  }) async {
    final label = isIncome ? 'income' : 'expense';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Remove "${category.name}"? Existing $label transactions keep this label.',
        ),
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
    if (confirmed == true && category.id != null) {
      if (isIncome) {
        await _db.deleteIncomeCategory(category.id!);
      } else {
        await _db.deleteCategory(category.id!);
      }
      widget.onChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = _showIncome ? _incomeCategories : _categories;
    final isIncome = _showIncome;

    return ManageListScaffold(
      addLabel: isIncome ? 'Add income category' : 'Add expense category',
      onAdd: () => _openEditor(isIncome: isIncome),
      padding: const EdgeInsets.fromLTRB(16, AppTheme.screenTopPadding, 16, 16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Expenses')),
            ButtonSegment(value: true, label: Text('Income')),
          ],
          selected: {_showIncome},
          onSelectionChanged: (selected) {
            setState(() => _showIncome = selected.first);
          },
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            isIncome ? 'Income categories' : 'Expense categories',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No categories yet.')),
          )
        else
          ...categories.map(
            (category) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(
                    category.colorValue,
                  ).withValues(alpha: 0.16),
                  child: Icon(
                    Icons.category_rounded,
                    color: Color(category.colorValue),
                  ),
                ),
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          _openEditor(category: category, isIncome: isIncome),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          _deleteCategory(category, isIncome: isIncome),
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
