import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/expense.dart';

const int _defaultAccountColor = 0xFF374151;

const List<Map<String, Object>> _defaultCategories = [
  {'name': 'Food', 'color': 0xFFFBCFE8},
  {'name': 'Transport', 'color': 0xFFFFEDD5},
  {'name': 'Shopping', 'color': 0xFFFEF08A},
  {'name': 'Bills', 'color': 0xFFDDD6FE},
  {'name': 'Entertainment', 'color': 0xFFFDBA74},
  {'name': 'Health', 'color': 0xFFD9F99D},
  {'name': 'General', 'color': 0xFF94A3B8},
  {'name': 'Other', 'color': 0xFFE2E8F0},
];

const List<Map<String, Object>> _defaultIncomeCategories = [
  {'name': 'Salary', 'color': 0xFF86EFAC},
  {'name': 'Bonus', 'color': 0xFF67E8F9},
  {'name': 'Allowance', 'color': 0xFFA5B4FC},
  {'name': 'Other', 'color': 0xFFE2E8F0},
];

class DBService {
  DBService._();
  static final DBService instance = DBService._();

  Database? _db;
  final List<Expense> _memoryExpenses = <Expense>[];
  final List<Account> _memoryAccounts = <Account>[];
  final List<ExpenseCategory> _memoryCategories = <ExpenseCategory>[];
  final List<ExpenseCategory> _memoryIncomeCategories = <ExpenseCategory>[];
  final List<Budget> _memoryBudgets = <Budget>[];
  bool _useMemoryStore = kIsWeb;
  bool _categoriesSeeded = false;
  bool _incomeCategoriesSeeded = false;

  Future<void> _ensureReady() async {
    if (_useMemoryStore || _db != null) {
      return;
    }

    try {
      await init();
    } catch (_) {
      _useMemoryStore = true;
      _db = null;
    }

    if (_db == null) {
      _useMemoryStore = true;
    }
  }

  Future<void> init() async {
    if (_useMemoryStore) {
      await _seedDefaultCategoriesIfNeeded();
      return;
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'expenses.db');
      _db = await openDatabase(
        path,
        version: 7,
        onCreate: (db, v) async {
          await _createSchema(db);
          await _seedDefaultCategories(db);
          await _seedDefaultIncomeCategories(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE expenses ADD COLUMN accountType TEXT NOT NULL DEFAULT 'cash'",
            );
            await db.execute(
              "ALTER TABLE expenses ADD COLUMN transactionType TEXT NOT NULL DEFAULT 'expense'",
            );
          }
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS accounts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                balance REAL NOT NULL,
                createdAt TEXT NOT NULL
              )
            ''');
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE accounts ADD COLUMN color INTEGER');
            await db.update('accounts', <String, Object?>{
              'color': _defaultAccountColor,
            }, where: 'color IS NULL');
          }
          if (oldVersion < 5) {
            await db.execute(
              "ALTER TABLE expenses ADD COLUMN title TEXT NOT NULL DEFAULT ''",
            );
            await db.execute('''
              CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                color INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS budgets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                categoryName TEXT NOT NULL DEFAULT '',
                amount REAL NOT NULL,
                year INTEGER NOT NULL,
                month INTEGER NOT NULL
              )
            ''');
            await _seedDefaultCategories(db);
          }
          if (oldVersion < 6) {
            await _seedDefaultCategories(db);
          }
          if (oldVersion < 7) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS income_categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                color INTEGER NOT NULL
              )
            ''');
            await _seedDefaultIncomeCategories(db);
          }
        },
      );
    } catch (_) {
      _useMemoryStore = true;
      _db = null;
      await _seedDefaultCategoriesIfNeeded();
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        accountType TEXT NOT NULL,
        transactionType TEXT NOT NULL,
        notes TEXT,
        receiptPath TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL,
        color INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE income_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryName TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    for (final item in _defaultCategories) {
      await db.insert('categories', <String, Object>{
        'name': item['name']!,
        'color': item['color']!,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedDefaultIncomeCategories(Database db) async {
    for (final item in _defaultIncomeCategories) {
      await db.insert('income_categories', <String, Object>{
        'name': item['name']!,
        'color': item['color']!,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedDefaultCategoriesIfNeeded() async {
    if (!_incomeCategoriesSeeded) {
      var id = 1;
      if (_memoryIncomeCategories.isEmpty) {
        for (final item in _defaultIncomeCategories) {
          _memoryIncomeCategories.add(
            ExpenseCategory(
              id: id++,
              name: item['name']! as String,
              colorValue: item['color']! as int,
            ),
          );
        }
      }
      _incomeCategoriesSeeded = true;
    }
    if (_categoriesSeeded && _memoryCategories.isNotEmpty) {
      _ensureOtherCategoryInMemory();
      return;
    }
    if (_memoryCategories.isEmpty) {
      var id = 1;
      for (final item in _defaultCategories) {
        _memoryCategories.add(
          ExpenseCategory(
            id: id++,
            name: item['name']! as String,
            colorValue: item['color']! as int,
          ),
        );
      }
    } else {
      _ensureOtherCategoryInMemory();
    }
    _categoriesSeeded = true;
  }

  void _ensureOtherCategoryInMemory() {
    if (_memoryCategories.any((category) => category.name == 'Other')) {
      return;
    }
    final nextId = _nextId(
      _memoryCategories.map((category) => category.id).toList(),
    );
    _memoryCategories.add(
      ExpenseCategory(id: nextId, name: 'Other', colorValue: 0xFFE2E8F0),
    );
  }

  int _nextId(List<int?> ids) {
    if (ids.isEmpty) {
      return 1;
    }
    return ids.map((id) => id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<int> insertExpense(Expense e) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final nextId = _nextId(
        _memoryExpenses.map((expense) => expense.id).toList(),
      );
      _memoryExpenses.add(
        Expense(
          id: nextId,
          title: e.title,
          amount: e.amount,
          currency: e.currency,
          date: e.date,
          category: e.category,
          accountType: e.accountType,
          transactionType: e.transactionType,
          notes: e.notes,
          receiptPath: e.receiptPath,
        ),
      );
      return nextId;
    }

    return await _db!.insert('expenses', e.toMap());
  }

  Future<int> insertAccount(Account account) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final nextId = _nextId(_memoryAccounts.map((item) => item.id).toList());
      _memoryAccounts.add(
        Account(
          id: nextId,
          name: account.name,
          balance: account.balance,
          colorValue: account.colorValue,
          createdAt: account.createdAt,
        ),
      );
      return nextId;
    }

    return await _db!.insert('accounts', account.toMap());
  }

  Future<int> insertCategory(ExpenseCategory category) async {
    await _ensureReady();
    await _seedDefaultCategoriesIfNeeded();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final nextId = _nextId(_memoryCategories.map((item) => item.id).toList());
      _memoryCategories.add(
        ExpenseCategory(
          id: nextId,
          name: category.name,
          colorValue: category.colorValue,
        ),
      );
      return nextId;
    }

    return await _db!.insert('categories', category.toMap());
  }

  Future<int> insertIncomeCategory(ExpenseCategory category) async {
    await _ensureReady();
    await _seedDefaultCategoriesIfNeeded();

    if (_useMemoryStore || _db == null) {
      final nextId = _nextId(
        _memoryIncomeCategories.map((item) => item.id).toList(),
      );
      _memoryIncomeCategories.add(
        ExpenseCategory(
          id: nextId,
          name: category.name,
          colorValue: category.colorValue,
        ),
      );
      return nextId;
    }

    return await _db!.insert('income_categories', category.toMap());
  }

  Future<int> insertBudget(Budget budget) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final nextId = _nextId(_memoryBudgets.map((item) => item.id).toList());
      _memoryBudgets.add(
        Budget(
          id: nextId,
          categoryName: budget.categoryName,
          amount: budget.amount,
          year: budget.year,
          month: budget.month,
        ),
      );
      return nextId;
    }

    return await _db!.insert('budgets', budget.toMap());
  }

  Future<int> updateAccount(Account account) async {
    if (account.id == null) {
      return 0;
    }

    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final index = _memoryAccounts.indexWhere((item) => item.id == account.id);
      if (index == -1) {
        return 0;
      }
      _memoryAccounts[index] = account;
      return 1;
    }

    return await _db!.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> updateCategory(ExpenseCategory category) async {
    if (category.id == null) {
      return 0;
    }

    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final index = _memoryCategories.indexWhere(
        (item) => item.id == category.id,
      );
      if (index == -1) {
        return 0;
      }
      _memoryCategories[index] = category;
      return 1;
    }

    return await _db!.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> updateIncomeCategory(ExpenseCategory category) async {
    if (category.id == null) {
      return 0;
    }

    await _ensureReady();
    await _seedDefaultCategoriesIfNeeded();

    if (_useMemoryStore || _db == null) {
      final index = _memoryIncomeCategories.indexWhere(
        (item) => item.id == category.id,
      );
      if (index == -1) {
        return 0;
      }
      _memoryIncomeCategories[index] = category;
      return 1;
    }

    return await _db!.update(
      'income_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> updateBudget(Budget budget) async {
    if (budget.id == null) {
      return 0;
    }

    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final index = _memoryBudgets.indexWhere((item) => item.id == budget.id);
      if (index == -1) {
        return 0;
      }
      _memoryBudgets[index] = budget;
      return 1;
    }

    return await _db!.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> updateExpense(Expense e) async {
    if (e.id == null) {
      return 0;
    }

    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final index = _memoryExpenses.indexWhere((expense) => expense.id == e.id);
      if (index == -1) {
        return 0;
      }
      _memoryExpenses[index] = e;
      return 1;
    }

    return await _db!.update(
      'expenses',
      e.toMap(),
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<List<Expense>> getAllExpenses() async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final items = List<Expense>.from(_memoryExpenses);
      items.sort((left, right) => right.date.compareTo(left.date));
      return items;
    }

    final rows = await _db!.query('expenses', orderBy: 'date DESC');
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  Future<List<Expense>> searchExpenses({
    String query = '',
    String? category,
    int? year,
    int? month,
  }) async {
    final items = await getAllExpenses();
    final normalized = query.trim().toLowerCase();

    return items.where((expense) {
      if (category != null &&
          category.isNotEmpty &&
          expense.category != category) {
        return false;
      }
      if (year != null && expense.date.year != year) {
        return false;
      }
      if (month != null && expense.date.month != month) {
        return false;
      }
      if (normalized.isEmpty) {
        return true;
      }
      final haystack =
          '${expense.displayTitle} ${expense.category} ${expense.notes ?? ''}'
              .toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  Future<List<Account>> getAllAccounts() async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final items = List<Account>.from(_memoryAccounts);
      items.sort((left, right) => left.name.compareTo(right.name));
      return items;
    }

    final rows = await _db!.query('accounts', orderBy: 'createdAt DESC');
    return rows.map((r) => Account.fromMap(r)).toList();
  }

  Future<List<ExpenseCategory>> getAllCategories() async {
    await _ensureReady();
    await _seedDefaultCategoriesIfNeeded();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final items = List<ExpenseCategory>.from(_memoryCategories);
      items.sort((left, right) => left.name.compareTo(right.name));
      return items;
    }

    final rows = await _db!.query('categories', orderBy: 'name ASC');
    if (rows.isEmpty) {
      await _seedDefaultCategories(_db!);
      final seeded = await _db!.query('categories', orderBy: 'name ASC');
      return seeded.map((r) => ExpenseCategory.fromMap(r)).toList();
    }
    return rows.map((r) => ExpenseCategory.fromMap(r)).toList();
  }

  Future<List<ExpenseCategory>> getAllIncomeCategories() async {
    await _ensureReady();
    await _seedDefaultCategoriesIfNeeded();

    if (_useMemoryStore || _db == null) {
      final items = List<ExpenseCategory>.from(_memoryIncomeCategories);
      items.sort((left, right) => left.name.compareTo(right.name));
      return items;
    }

    final rows = await _db!.query('income_categories', orderBy: 'name ASC');
    return rows.map((r) => ExpenseCategory.fromMap(r)).toList();
  }

  Future<List<Budget>> getAllBudgets() async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      return List<Budget>.from(_memoryBudgets);
    }

    final rows = await _db!.query('budgets', orderBy: 'year DESC, month DESC');
    return rows.map((r) => Budget.fromMap(r)).toList();
  }

  Future<Budget?> getBudgetForMonth({
    required int year,
    required int month,
    String categoryName = '',
  }) async {
    final budgets = await getAllBudgets();
    for (final budget in budgets) {
      if (budget.year == year &&
          budget.month == month &&
          budget.categoryName == categoryName) {
        return budget;
      }
    }
    return null;
  }

  Future<int> deleteExpense(int id) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final before = _memoryExpenses.length;
      _memoryExpenses.removeWhere((expense) => expense.id == id);
      return before - _memoryExpenses.length;
    }

    return await _db!.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAccount(int id) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final before = _memoryAccounts.length;
      _memoryAccounts.removeWhere((account) => account.id == id);
      return before - _memoryAccounts.length;
    }

    return await _db!.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final before = _memoryCategories.length;
      _memoryCategories.removeWhere((category) => category.id == id);
      return before - _memoryCategories.length;
    }

    return await _db!.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteIncomeCategory(int id) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      final before = _memoryIncomeCategories.length;
      _memoryIncomeCategories.removeWhere((category) => category.id == id);
      return before - _memoryIncomeCategories.length;
    }

    return await _db!.delete(
      'income_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBudget(int id) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final before = _memoryBudgets.length;
      _memoryBudgets.removeWhere((budget) => budget.id == id);
      return before - _memoryBudgets.length;
    }

    return await _db!.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      _memoryExpenses.clear();
      _memoryAccounts.clear();
      _memoryBudgets.clear();
      _memoryCategories.clear();
      _memoryIncomeCategories.clear();
      _categoriesSeeded = false;
      _incomeCategoriesSeeded = false;
      await _seedDefaultCategoriesIfNeeded();
      return;
    }

    await _db!.delete('expenses');
    await _db!.delete('accounts');
    await _db!.delete('budgets');
    await _db!.delete('categories');
    await _db!.delete('income_categories');
    await _seedDefaultCategories(_db!);
    await _seedDefaultIncomeCategories(_db!);
  }
}
