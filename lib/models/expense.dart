class Expense {
  final int? id;
  final double amount;
  final String currency;
  final DateTime date;
  final String category;
  final String accountType;
  final String transactionType;
  final String? notes;
  final String? receiptPath;

  Expense({
    this.id,
    required this.amount,
    required this.currency,
    required this.date,
    required this.category,
    required this.accountType,
    required this.transactionType,
    this.notes,
    this.receiptPath,
  });

  bool get isIncome => transactionType == 'income';

  bool get isExpense => transactionType == 'expense';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'date': date.toIso8601String(),
      'category': category,
      'accountType': accountType,
      'transactionType': transactionType,
      'notes': notes,
      'receiptPath': receiptPath,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> m) {
    return Expense(
      id: m['id'] as int?,
      amount: (m['amount'] as num).toDouble(),
      currency: (m['currency'] as String?) ?? 'USD',
      date: DateTime.parse(m['date'] as String),
      category: (m['category'] as String?) ?? 'General',
      accountType: (m['accountType'] as String?) ?? 'cash',
      transactionType: (m['transactionType'] as String?) ?? 'expense',
      notes: m['notes'] as String?,
      receiptPath: m['receiptPath'] as String?,
    );
  }
}
