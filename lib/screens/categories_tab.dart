import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/category.dart';
import '../services/db_service.dart';

class _CategorySheetResult {
  const _CategorySheetResult({required this.name, required this.colorValue});

  final String name;
  final int colorValue;
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({this.category});

  final ExpenseCategory? category;

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
    Navigator.of(context).pop(
      _CategorySheetResult(name: name, colorValue: _selectedColor),
    );
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
            widget.category == null ? 'New category' : 'Edit category',
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
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Save'),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _db.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = items;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([ExpenseCategory? category]) async {
    final result = await showModalBottomSheet<_CategorySheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryEditorSheet(category: category),
    );

    if (result == null || !mounted) {
      return;
    }

    if (category == null) {
      await _db.insertCategory(
        ExpenseCategory(name: result.name, colorValue: result.colorValue),
      );
    } else {
      await _db.updateCategory(
        ExpenseCategory(
          id: category.id,
          name: result.name,
          colorValue: result.colorValue,
        ),
      );
    }
    widget.onChanged();
    await _load();
  }

  Future<void> _deleteCategory(ExpenseCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Remove "${category.name}"? Expenses keep this label.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.expenseTint)),
          ),
        ],
      ),
    );
    if (confirmed == true && category.id != null) {
      await _db.deleteCategory(category.id!);
      widget.onChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, AppTheme.screenTopPadding, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Category list',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        if (_categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No categories yet. Tap + to add one.'),
            ),
          )
        else
          ..._categories.map(
            (category) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Color(category.colorValue).withValues(alpha: 0.16),
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
                      onPressed: () => _openEditor(category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteCategory(category),
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
