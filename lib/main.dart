import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/expense.dart';
import 'services/db_service.dart';

const String kCashAccount = 'cash';
const String kBankAccount = 'bank';
const String kIncomeType = 'income';
const String kExpenseType = 'expense';

const Color kPrimaryBlue = Color(0xFF0A84FF);
const Color kPrimaryBlueDeep = Color(0xFF1D4ED8);
const Color kSurface = Color(0xFFF4F7FB);
const Color kTextPrimary = Color(0xFF111827);
const Color kTextSecondary = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kCashTint = Color(0xFF5AC8FA);
const Color kBankTint = Color(0xFF3B82F6);
const Color kIncomeTint = Color(0xFF34C759);
const Color kExpenseTint = Color(0xFFFF9500);

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryBlue),
        scaffoldBackgroundColor: Colors.white,
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

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddTransactionSheet(
          amountController: amountController,
          categoryController: categoryController,
          noteController: noteController,
          accountType: accountType,
          transactionType: transactionType,
          onAccountTypeChanged: (value) => accountType = value,
          onTransactionTypeChanged: (value) => transactionType = value,
        );
      },
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
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddTransactionSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedTab,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return _TabShell(
      title: 'Home',
      subtitle: 'Track income and expenses from one clean dashboard.',
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _HomeHeroCard(
              incomeTotal: incomeTotal,
              expenseTotal: expenseTotal,
              netTotal: netTotal,
            ),
            const SizedBox(height: 16),
            _SummaryStrip(
              leftLabel: 'Income',
              leftValue: _money(incomeTotal),
              middleLabel: 'Expenses',
              middleValue: _money(expenseTotal),
              rightLabel: 'Net',
              rightValue: _money(netTotal),
            ),
            const SizedBox(height: 18),
            _SectionHeader(
                title: 'Recent activity', action: '${expenses.length} records'),
            const SizedBox(height: 10),
            if (loading)
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
              ...expenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TransactionCard(
                    expense: expense,
                    onDelete: () => onDelete(expense),
                  ),
                ),
              ),
          ],
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
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
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
          colors: [Color(0xFF0A84FF), Color(0xFF64D2FF)],
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
    return Row(
      children: [
        Expanded(
            child: _SummaryChip(
                label: leftLabel,
                value: leftValue,
                color: const Color(0xFF10B981))),
        const SizedBox(width: 12),
        Expanded(
            child: _SummaryChip(
                label: middleLabel,
                value: middleValue,
                color: const Color(0xFFEF4444))),
        const SizedBox(width: 12),
        Expanded(
            child: _SummaryChip(
                label: rightLabel, value: rightValue, color: kPrimaryBlueDeep)),
      ],
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
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
              expense.isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${expense.isIncome ? '+' : '-'}${_money(expense.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            _Badge(label: expense.accountType, color: accountColor),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${expense.category} • ${expense.transactionType} • ${expense.notes?.isNotEmpty == true ? expense.notes : 'No note'} • ${_formatDate(expense.date)}',
            style: const TextStyle(height: 1.25),
          ),
        ),
        trailing: onDelete == null
            ? null
            : IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
              ),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10)),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
        color: kSurface,
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
                ?.copyWith(color: Colors.black54),
          ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.pie_chart_rounded,
                label: 'Stats',
                active: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
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

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet({
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
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('Add transaction',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: widget.amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Account type',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
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
                const SizedBox(height: 12),
                Text('Transaction type',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
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
                const SizedBox(height: 12),
                TextField(
                  controller: widget.noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

Color _chartColor(int index) {
  const colors = [
    Color(0xFF0A84FF),
    Color(0xFF06B6D4),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF64748B),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];
  return colors[index % colors.length];
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
