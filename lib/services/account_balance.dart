import '../models/expense.dart';

const String _kCashAccount = 'cash';

/// Computes running balance from recorded transactions for an account id/name.
double balanceFromExpenses(String accountType, List<Expense> expenses) {
  return expenses.fold<double>(0, (sum, expense) {
    if (expense.accountType != accountType) {
      return sum;
    }
    final signed = expense.isIncome ? expense.amount : -expense.amount;
    return sum + signed;
  });
}

/// Balance map for cash + every custom account name.
Map<String, double> balancesForAllAccounts(
  List<Expense> expenses,
  List<String> customAccountNames,
) {
  final balances = <String, double>{
    _kCashAccount: balanceFromExpenses(_kCashAccount, expenses),
  };
  for (final name in customAccountNames) {
    balances[name] = balanceFromExpenses(name, expenses);
  }
  return balances;
}
