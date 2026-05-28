import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/expense.dart';

const int _defaultAccountColor = 0xFF374151;

class DBService {
  DBService._();
  static final DBService instance = DBService._();

  Database? _db;
  final List<Expense> _memoryExpenses = <Expense>[];
  final List<Account> _memoryAccounts = <Account>[];
  bool _useMemoryStore = kIsWeb;

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
      return;
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'expenses.db');
      _db = await openDatabase(
        path,
        version: 4,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                "ALTER TABLE expenses ADD COLUMN accountType TEXT NOT NULL DEFAULT 'cash'");
            await db.execute(
                "ALTER TABLE expenses ADD COLUMN transactionType TEXT NOT NULL DEFAULT 'expense'");
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
            await db.update(
              'accounts',
              <String, Object?>{'color': _defaultAccountColor},
              where: 'color IS NULL',
            );
          }
        },
      );
    } catch (_) {
      _useMemoryStore = true;
      _db = null;
    }
  }

  Future<int> insertExpense(Expense e) async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      final nextId = _memoryExpenses.isEmpty
          ? 1
          : (_memoryExpenses
                  .map((expense) => expense.id ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1);
      _memoryExpenses.add(
        Expense(
          id: nextId,
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
      final nextId = _memoryAccounts.isEmpty
          ? 1
          : (_memoryAccounts
                  .map((item) => item.id ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1);
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

  Future<void> clearAll() async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      _memoryExpenses.clear();
      _memoryAccounts.clear();
      return;
    }

    await _db!.delete('expenses');
    await _db!.delete('accounts');
  }
}
