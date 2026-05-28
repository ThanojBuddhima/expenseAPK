import 'package:flutter_test/flutter_test.dart';

import 'package:expence_apk/models/account.dart';
import 'package:expence_apk/models/expense.dart';
import 'package:expence_apk/services/db_service.dart';

void main() {
  final db = DBService.instance;

  setUp(() async {
    await db.init();
    await db.clearAll();
  });

  tearDown(() async {
    await db.clearAll();
  });

  test('inserts, reads, and deletes expenses', () async {
    final expense = Expense(
      amount: 42.5,
      currency: 'USD',
      date: DateTime(2026, 5, 28),
      category: 'Food',
      accountType: 'cash',
      transactionType: 'expense',
      notes: 'Lunch',
    );

    final id = await db.insertExpense(expense);
    final items = await db.getAllExpenses();

    expect(id, greaterThan(0));
    expect(items, hasLength(1));
    expect(items.first.amount, 42.5);
    expect(items.first.category, 'Food');
    expect(items.first.accountType, 'cash');
    expect(items.first.transactionType, 'expense');

    final deleted = await db.deleteExpense(items.first.id!);
    final afterDelete = await db.getAllExpenses();

    expect(deleted, 1);
    expect(afterDelete, isEmpty);
  });

  test('stores income transactions separately from expenses', () async {
    await db.insertExpense(
      Expense(
        amount: 100,
        currency: 'USD',
        date: DateTime(2026, 5, 28),
        category: 'Salary',
        accountType: 'bank',
        transactionType: 'income',
      ),
    );

    final items = await db.getAllExpenses();

    expect(items, hasLength(1));
    expect(items.first.isIncome, isTrue);
    expect(items.first.accountType, 'bank');
  });

  test('inserts and reads custom accounts', () async {
    final account = Account(
      name: 'Savings',
      balance: 250.0,
      colorValue: 0xFF06B6D4,
    );

    final id = await db.insertAccount(account);
    final accounts = await db.getAllAccounts();

    expect(id, greaterThan(0));
    expect(accounts, hasLength(1));
    expect(accounts.first.name, 'Savings');
    expect(accounts.first.balance, 250.0);
    expect(accounts.first.colorValue, 0xFF06B6D4);
  });

  test('deletes custom accounts', () async {
    final id = await db.insertAccount(
      Account(
        name: 'Wallet',
        balance: 40.0,
        colorValue: 0xFFF59E0B,
      ),
    );

    final deleted = await db.deleteAccount(id);
    final accounts = await db.getAllAccounts();

    expect(deleted, 1);
    expect(accounts, isEmpty);
  });
}
