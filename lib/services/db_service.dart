import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DBService {
  DBService._();
  static final DBService instance = DBService._();

  Database? _db;
  final List<Expense> _memoryExpenses = <Expense>[];
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
        version: 2,
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
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                "ALTER TABLE expenses ADD COLUMN accountType TEXT NOT NULL DEFAULT 'cash'");
            await db.execute(
                "ALTER TABLE expenses ADD COLUMN transactionType TEXT NOT NULL DEFAULT 'expense'");
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

  Future<void> clearAll() async {
    await _ensureReady();

    if (_useMemoryStore || _db == null) {
      _useMemoryStore = true;
      _memoryExpenses.clear();
      return;
    }

    await _db!.delete('expenses');
  }
}
