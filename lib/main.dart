import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/expense.dart';
import 'services/db_service.dart';

const String kCashAccount = 'cash';
const String kBankAccount = 'bank';
const String kIncomeType = 'income';
const String kExpenseType = 'expense';

const Color kPrimaryBlue = Color(0xFFFF9500);
const Color kPrimaryBlueDeep = Color(0xFFE07A00);
const Color kSurface = Color(0xFFFFFCF8);
const Color kTextPrimary = Color(0xFF111827);
const Color kTextSecondary = Color(0xFF6B7280);
const Color kBorder = Colors.transparent;
const Color kCashTint = Color(0xFF9CA3AF);
const Color kBankTint = Color(0xFF6B7280);
const Color kIncomeTint = Color(0xFF34C759);
const Color kExpenseTint = Color(0xFFFF9500);

enum FilterMode { daily, weekly, monthly, annually }

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBService.instance.init();
  runApp(const MyApp());
}

void main() {
  initializeApp();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Offline Expense Manager',
      scrollBehavior: const _NoScrollbarBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryBlue),
        scaffoldBackgroundColor: const Color(0xFFFFFCF8),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(color: kTextSecondary),
        ),
      ),
      home: const ExpenseDashboardPage(),
    );
  }
}

class ExpenseDashboardPage extends StatefulWidget {
  const ExpenseDashboardPage({super.key});

  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage> {
  final DBService _db = DBService.instance;

  List<Expense> _expenses = <Expense>[];
  bool _loading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _reloadExpenses();
  }

  Future<void> _reloadExpenses() async {
    setState(() {
      _loading = true;
    });

    final items = await _db.getAllExpenses();
    if (!mounted) {
      return;
    }

    setState(() {
      _expenses = items;
      _loading = false;
    });
  }

  Future<void> _openAddTransactionSheet() async {
    final amountController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    final noteController = TextEditingController();

    String accountType = kCashAccount;
    String transactionType = kExpenseType;

    final shouldSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return _AddTransactionPage(
            amountController: amountController,
            categoryController: categoryController,
            noteController: noteController,
            accountType: accountType,
            transactionType: transactionType,
            onAccountTypeChanged: (value) => accountType = value,
            onTransactionTypeChanged: (value) => transactionType = value,
          );
        },
      ),
    );

    final amount = double.tryParse(amountController.text.trim());
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();

    if (shouldSave != true || amount == null || amount <= 0) {
      return;
    }

    await _db.insertExpense(
      Expense(
        amount: amount,
        currency: 'USD',
        date: DateTime.now(),
        category: categoryController.text.trim().isEmpty
            ? 'General'
            : categoryController.text.trim(),
        accountType: accountType,
        transactionType: transactionType,
        notes: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      ),
    );

    await _reloadExpenses();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTab = 0;
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.id == null) {
      return;
    }

    await _db.deleteExpense(expense.id!);
    await _reloadExpenses();
  }

  List<Expense> get _orderedExpenses {
    final items = List<Expense>.from(_expenses);
    items.sort((left, right) => right.date.compareTo(left.date));
    return items;
  }

  double get _incomeTotal => _expenses
      .where((expense) => expense.isIncome)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  double get _expenseTotal => _expenses
      .where((expense) => expense.isExpense)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  double get _netTotal => _incomeTotal - _expenseTotal;

  double get _cashBalance {
    return _expenses.fold<double>(0, (sum, expense) {
      final signedAmount = expense.isIncome ? expense.amount : -expense.amount;
      return expense.accountType == kCashAccount ? sum + signedAmount : sum;
    });
  }

  double get _bankBalance {
    return _expenses.fold<double>(0, (sum, expense) {
      final signedAmount = expense.isIncome ? expense.amount : -expense.amount;
      return expense.accountType == kBankAccount ? sum + signedAmount : sum;
    });
  }

  Map<String, double> get _categoryTotals {
    final totals = <String, double>{};
    for (final expense in _expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  Map<String, double> get _accountTotals {
    return <String, double>{
      kCashAccount: _cashBalance,
      kBankAccount: _bankBalance,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(
        loading: _loading,
        expenses: _orderedExpenses,
        incomeTotal: _incomeTotal,
        expenseTotal: _expenseTotal,
        netTotal: _netTotal,
        onRefresh: _reloadExpenses,
        onDelete: _deleteExpense,
      ),
      _StatsTab(
        loading: _loading,
        expenses: _orderedExpenses,
        incomeTotal: _incomeTotal,
        expenseTotal: _expenseTotal,
        netTotal: _netTotal,
        categoryTotals: _categoryTotals,
      ),
      _AccountsTab(
        loading: _loading,
        expenses: _orderedExpenses,
        accountTotals: _accountTotals,
        netTotal: _netTotal,
      ),
      const _SettingsTab(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedTab, children: pages),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedTab,
        onAdd: _openAddTransactionSheet,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.loading,
    required this.expenses,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.netTotal,
    required this.onRefresh,
    required this.onDelete,
  });

  final bool loading;
  final List<Expense> expenses;
  final double incomeTotal;
  final double expenseTotal;
  final double netTotal;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Expense expense) onDelete;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  FilterMode _mode = FilterMode.daily;

  List<Expense> get _filteredExpenses {
    final now = DateTime.now();
    switch (_mode) {
      case FilterMode.daily:
        return widget.expenses.where((e) {
          return e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day;
        }).toList();
      case FilterMode.weekly:
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return widget.expenses.where((e) {
          return e.date
                  .isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(now.add(const Duration(days: 1)));
        }).toList();
      case FilterMode.monthly:
        return widget.expenses.where((e) {
          return e.date.year == now.year && e.date.month == now.month;
        }).toList();
      case FilterMode.annually:
        return widget.expenses.where((e) => e.date.year == now.year).toList();
    }
  }

  double _sumIncome(List<Expense> list) => list
      .where((expense) => expense.isIncome)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  double _sumExpense(List<Expense> list) => list
      .where((expense) => expense.isExpense)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  String _modeLabel() {
    switch (_mode) {
      case FilterMode.daily:
        return 'Daily';
      case FilterMode.weekly:
        return 'Weekly';
      case FilterMode.monthly:
        return 'Monthly';
      case FilterMode.annually:
        return 'Annual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = _filteredExpenses;
    final incomeTotal = _sumIncome(expenses);
    final expenseTotal = _sumExpense(expenses);
    final netTotal = incomeTotal - expenseTotal;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
            children: [
              _TransactionsTopBar(monthLabel: _monthYearLabel(DateTime.now())),
              const SizedBox(height: 10),
              _TransactionsModeBar(
                  mode: _mode, onChanged: (m) => setState(() => _mode = m)),
              const SizedBox(height: 10),
              _SummaryStrip(
                leftLabel: 'Income',
                leftValue: _money(incomeTotal),
                middleLabel: 'Expenses',
                middleValue: _money(expenseTotal),
                rightLabel: 'Total',
                rightValue: _money(netTotal),
              ),
              const SizedBox(height: 12),
              _SectionHeader(
                title: _modeLabel(),
                action: '${expenses.length} transactions',
              ),
              const SizedBox(height: 8),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (expenses.isEmpty)
                const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  subtitle:
                      'Tap the + button to add your first income or expense.',
                )
              else
                ..._groupExpensesByDate(expenses).entries.expand(
                      (entry) => [
                        _DayTransactionGroupHeader(
                          date: entry.key,
                          expenses: entry.value,
                        ),
                        const SizedBox(height: 8),
                        ...entry.value.map(
                          (expense) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TransactionCard(
                              expense: expense,
                              onDelete: () => widget.onDelete(expense),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.loading,
    required this.expenses,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.netTotal,
    required this.categoryTotals,
  });

  final bool loading;
  final List<Expense> expenses;
  final double incomeTotal;
  final double expenseTotal;
  final double netTotal;
  final Map<String, double> categoryTotals;

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      title: 'Stats',
      subtitle: 'See history, category splits, and a quick summary.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _SummaryGrid(
                  items: [
                    _MiniMetric(
                        label: 'Income',
                        value: _money(incomeTotal),
                        color: kIncomeTint),
                    _MiniMetric(
                        label: 'Expense',
                        value: _money(expenseTotal),
                        color: kExpenseTint),
                    _MiniMetric(
                        label: 'Net',
                        value: _money(netTotal),
                        color: kPrimaryBlueDeep),
                    _MiniMetric(
                        label: 'Entries',
                        value: '${expenses.length}',
                        color: kCashTint),
                  ],
                ),
                const SizedBox(height: 16),
                _PieCard(categoryTotals: categoryTotals),
                const SizedBox(height: 16),
                _SectionHeader(
                    title: 'History', action: '${expenses.length} total'),
                const SizedBox(height: 10),
                if (expenses.isEmpty)
                  const _EmptyState(
                    icon: Icons.pie_chart_outline,
                    title: 'No history yet',
                    subtitle:
                        'Add a few transactions and the chart will appear here.',
                  )
                else
                  ...expenses.take(10).map(
                        (expense) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TransactionCard(expense: expense),
                        ),
                      ),
              ],
            ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({
    required this.loading,
    required this.expenses,
    required this.accountTotals,
    required this.netTotal,
  });

  final bool loading;
  final List<Expense> expenses;
  final Map<String, double> accountTotals;
  final double netTotal;

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      title: 'Accounts',
      subtitle: 'Cash and bank balances based on your transactions.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _SummaryGrid(
                  items: [
                    _MiniMetric(
                        label: 'Cash',
                        value: _money(accountTotals[kCashAccount] ?? 0),
                        color: kCashTint),
                    _MiniMetric(
                        label: 'Bank',
                        value: _money(accountTotals[kBankAccount] ?? 0),
                        color: kBankTint),
                    _MiniMetric(
                        label: 'Net',
                        value: _money(netTotal),
                        color: kIncomeTint),
                    _MiniMetric(
                        label: 'Entries',
                        value: '${expenses.length}',
                        color: kExpenseTint),
                  ],
                ),
                const SizedBox(height: 16),
                _AccountBalanceCard(
                  title: 'Cash account',
                  amount: accountTotals[kCashAccount] ?? 0,
                  icon: Icons.payments_outlined,
                  color: kCashTint,
                ),
                const SizedBox(height: 12),
                _AccountBalanceCard(
                  title: 'Bank account',
                  amount: accountTotals[kBankAccount] ?? 0,
                  icon: Icons.account_balance_outlined,
                  color: kBankTint,
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                    title: 'Recent account activity',
                    action: '${expenses.length} items'),
                const SizedBox(height: 10),
                if (expenses.isEmpty)
                  const _EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No account activity yet',
                    subtitle:
                        'Add income or expense transactions to see balances change.',
                  )
                else
                  ...expenses.take(8).map(
                        (expense) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TransactionCard(expense: expense),
                        ),
                      ),
              ],
            ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      title: 'Settings',
      subtitle: 'Demo options and app preferences.',
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120),
        children: const [
          _SettingTile(title: 'Profile', subtitle: 'Demo user'),
          SizedBox(height: 12),
          _SettingTile(title: 'Theme', subtitle: 'Light mode'),
          SizedBox(height: 12),
          _SettingTile(title: 'Backup', subtitle: 'Local only demo'),
          SizedBox(height: 12),
          _SettingTile(title: 'Notifications', subtitle: 'Enabled'),
        ],
      ),
    );
  }
}

class _TabShell extends StatelessWidget {
  const _TabShell(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFEFF), Color(0xFFF5F7FB)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: kTextPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard(
      {required this.incomeTotal,
      required this.expenseTotal,
      required this.netTotal});

  final double incomeTotal;
  final double expenseTotal;
  final double netTotal;

  @override
  Widget build(BuildContext context) {
    final positive = netTotal >= 0;
    final progress =
        (expenseTotal == 0 ? 0.0 : incomeTotal / (incomeTotal + expenseTotal))
            .clamp(0.1, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFFB347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.20),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Offline ready',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.trending_up_rounded, color: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _money(netTotal),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
          ),
          const SizedBox(height: 6),
          Text(
              positive
                  ? 'You are currently positive'
                  : 'You are currently below zero',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.88))),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Income ${_money(incomeTotal)} • Expense ${_money(expenseTotal)}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.leftLabel,
    required this.leftValue,
    required this.middleLabel,
    required this.middleValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String middleLabel;
  final String middleValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryChip(
              label: leftLabel,
              value: leftValue,
              color: const Color(0xFF10B981),
            ),
          ),
          Expanded(
            child: _SummaryChip(
              label: middleLabel,
              value: middleValue,
              color: const Color(0xFFEF4444),
            ),
          ),
          Expanded(
            child: _SummaryChip(
              label: rightLabel,
              value: rightValue,
              color: kPrimaryBlueDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsTopBar extends StatelessWidget {
  const _TransactionsTopBar({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.chevron_left_rounded, color: kTextPrimary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const Icon(Icons.star_border_rounded, color: kTextPrimary),
        const SizedBox(width: 12),
        const Icon(Icons.search_rounded, color: kTextPrimary),
        const SizedBox(width: 12),
        const Icon(Icons.tune_rounded, color: kTextPrimary),
      ],
    );
  }
}

class _TransactionsModeBar extends StatelessWidget {
  const _TransactionsModeBar({required this.mode, required this.onChanged});

  final FilterMode mode;
  final ValueChanged<FilterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeTab(
            label: 'Daily',
            active: mode == FilterMode.daily,
            onTap: () => onChanged(FilterMode.daily)),
        const SizedBox(width: 16),
        _ModeTab(
            label: 'Weekly',
            active: mode == FilterMode.weekly,
            onTap: () => onChanged(FilterMode.weekly)),
        const SizedBox(width: 16),
        _ModeTab(
            label: 'Monthly',
            active: mode == FilterMode.monthly,
            onTap: () => onChanged(FilterMode.monthly)),
        const SizedBox(width: 16),
        _ModeTab(
            label: 'Annual',
            active: mode == FilterMode.annually,
            onTap: () => onChanged(FilterMode.annually)),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, this.active = false, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        active ? kPrimaryBlue : kTextPrimary.withOpacity(0.7),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 28,
              decoration: BoxDecoration(
                color: active ? kPrimaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: kPrimaryBlue.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: (MediaQuery.of(context).size.width - 44) / 2,
              child: item,
            ),
          )
          .toList(),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: kPrimaryBlue.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.circle, color: color, size: 18),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PieCard extends StatelessWidget {
  const _PieCard({required this.categoryTotals});

  final Map<String, double> categoryTotals;

  @override
  Widget build(BuildContext context) {
    if (categoryTotals.isEmpty) {
      return const _EmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No chart data yet',
        subtitle:
            'Your category pie chart will appear after you add transactions.',
      );
    }

    final items = categoryTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final segments = items
        .mapIndexed(
          (index, entry) => _PieSegment(
            label: entry.key,
            value: entry.value,
            color: index == 5 ? const Color(0xFF64748B) : _chartColor(index),
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: kPrimaryBlue.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category split',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.2,
            child: CustomPaint(
              painter: _PieChartPainter(segments),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${segments.length}',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const Text('categories'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: segments
                .map(
                  (segment) => _LegendPill(
                      label: segment.label,
                      value: _money(segment.value),
                      color: segment.color),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PieSegment {
  const _PieSegment(
      {required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter(this.segments);

  final List<_PieSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total =
        segments.fold<double>(0, (sum, segment) => sum + segment.value);
    if (total <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    canvas.drawCircle(
      center,
      radius * 0.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.expense, this.onDelete});

  final Expense expense;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = expense.isIncome ? kIncomeTint : kExpenseTint;
    final accountColor =
        expense.accountType == kCashAccount ? kCashTint : kBankTint;
    Color amountColor = expense.isIncome ? kIncomeTint : kExpenseTint;
    String formattedAmount = _formatCurrency(expense.currency, expense.amount);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Icon(
                Icons.attach_money,
                color: amountColor.withOpacity(0.9),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expense.category,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense.notes?.isNotEmpty == true
                        ? expense.notes!
                        : expense.transactionType,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense.accountType,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedAmount,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accountColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        expense.accountType,
                        style: TextStyle(
                          color: accountColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTransactionGroupHeader extends StatelessWidget {
  const _DayTransactionGroupHeader({
    required this.date,
    required this.expenses,
  });

  final DateTime date;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final income = expenses
        .where((expense) => expense.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expense = expenses
        .where((item) => item.isExpense)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final net = income - expense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  _weekdayLabel(date.weekday),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kTextPrimary.withOpacity(0.7),
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthYearLabel(date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${expenses.length} transactions',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(income),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kIncomeTint,
                ),
              ),
              Text(
                _money(expense),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kExpenseTint,
                ),
              ),
              Text(
                'Net ${_money(net)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kPrimaryBlueDeep,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard(
      {required this.title,
      required this.amount,
      required this.icon,
      required this.color});

  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Balance: ${_money(amount)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: kPrimaryBlue.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (action != null)
          Text(
            action!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: kTextPrimary.withOpacity(0.7)),
          ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NavItem(
              icon: Icons.receipt_long_rounded,
              label: 'Transactions',
              active: selectedIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.pie_chart_rounded,
              label: 'Stats',
              active: selectedIndex == 1,
              onTap: () => onTap(1),
            ),
            _AddNavItem(onTap: onAdd),
            _NavItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Accounts',
              active: selectedIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              active: selectedIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddNavItem extends StatelessWidget {
  const _AddNavItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: kPrimaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? kPrimaryBlue : kTextSecondary;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTransactionPage extends StatefulWidget {
  const _AddTransactionPage({
    required this.amountController,
    required this.categoryController,
    required this.noteController,
    required this.accountType,
    required this.transactionType,
    required this.onAccountTypeChanged,
    required this.onTransactionTypeChanged,
  });

  final TextEditingController amountController;
  final TextEditingController categoryController;
  final TextEditingController noteController;
  final String accountType;
  final String transactionType;
  final ValueChanged<String> onAccountTypeChanged;
  final ValueChanged<String> onTransactionTypeChanged;

  @override
  State<_AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<_AddTransactionPage> {
  late String _accountType;
  late String _transactionType;

  @override
  void initState() {
    super.initState();
    _accountType = widget.accountType;
    _transactionType = widget.transactionType;
  }

  void _save() {
    widget.onAccountTypeChanged(_accountType);
    widget.onTransactionTypeChanged(_transactionType);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Add transaction'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AddFieldSection(
              title: 'Amount',
              child: TextField(
                controller: widget.amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'Enter amount',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AddFieldSection(
              title: 'Category',
              child: TextField(
                controller: widget.categoryController,
                decoration: const InputDecoration(
                  hintText: 'General',
                  prefixIcon: Icon(Icons.category_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AddFieldSection(
              title: 'Account type',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: kCashAccount,
                      label: Text('Cash'),
                      icon: Icon(Icons.payments_outlined)),
                  ButtonSegment(
                      value: kBankAccount,
                      label: Text('Bank'),
                      icon: Icon(Icons.account_balance_outlined)),
                ],
                selected: {_accountType},
                onSelectionChanged: (value) {
                  setState(() {
                    _accountType = value.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            _AddFieldSection(
              title: 'Transaction type',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: kExpenseType,
                      label: Text('Expense'),
                      icon: Icon(Icons.remove_circle_outline)),
                  ButtonSegment(
                      value: kIncomeType,
                      label: Text('Income'),
                      icon: Icon(Icons.add_circle_outline)),
                ],
                selected: {_transactionType},
                onSelectionChanged: (value) {
                  setState(() {
                    _transactionType = value.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            _AddFieldSection(
              title: 'Note',
              child: TextField(
                controller: widget.noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Optional note',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFieldSection extends StatelessWidget {
  const _AddFieldSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _monthYearLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _weekdayLabel(int weekday) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[weekday - 1];
}

LinkedHashMap<DateTime, List<Expense>> _groupExpensesByDate(
  List<Expense> expenses,
) {
  final groups = LinkedHashMap<DateTime, List<Expense>>();

  for (final expense in expenses) {
    final date =
        DateTime(expense.date.year, expense.date.month, expense.date.day);
    groups.putIfAbsent(date, () => <Expense>[]).add(expense);
  }

  return groups;
}

Color _chartColor(int index) {
  const colors = [
    Color(0xFFFF9500),
    Color(0xFF9CA3AF),
    Color(0xFF16A34A),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFF6B7280),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];
  return colors[index % colors.length];
}

String _formatCurrency(String currency, double value) {
  // Simple formatter: support INR 'INR' or 'Rs' -> 'Rs. 1,500.00', otherwise fallback to dollar style
  String s = value.toStringAsFixed(2);
  final parts = s.split('.');
  final integer = parts[0];
  final fraction = parts.length > 1 ? parts[1] : '00';
  final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
  final withCommas = integer.replaceAllMapped(reg, (m) => ',${m.group(0)}');
  if (currency.toLowerCase() == 'inr' ||
      currency.toLowerCase() == 'rs' ||
      currency.toLowerCase() == 'rs.') {
    return 'Rs. $withCommas.$fraction';
  }
  // default
  return '\$${withCommas}.$fraction';
}

extension _IterableIndexExtension<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T element) convert) sync* {
    var index = 0;
    for (final item in this) {
      yield convert(index, item);
      index += 1;
    }
  }
}
