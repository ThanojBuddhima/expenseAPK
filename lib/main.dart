import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'models/account.dart';
import 'models/expense.dart';
import 'services/db_service.dart';

const String kCashAccount = 'cash';
const String kBankAccount = 'bank';
const String kIncomeType = 'income';
const String kExpenseType = 'expense';
const Color kPrimaryBlue = Color(0xFF1F2937);
const Color kPrimaryBlueDeep = Color(0xFF111827);
const Color kSurface = Color(0xFFFAFAFA);
const Color kTextPrimary = Color(0xFF111827);
const Color kTextSecondary = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kCashTint = Color(0xFF374151);
const Color kBankTint = Color(0xFF4B5563);
const Color kIncomeTint = Color(0xFF10B981);
const Color kExpenseTint = Color(0xFFEF4444);
const Color kInputBackground = Color(0xFFFAFAFA);
const List<Color> kAccountColorOptions = [
  kCashTint,
  kBankTint,
  kIncomeTint,
  kExpenseTint,
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
];

enum FilterMode { day, week, month, annually }

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: kSurface,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
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
  List<Account> _accounts = <Account>[];
  bool _loading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _reloadDashboard();
  }

  Future<void> _reloadDashboard() async {
    setState(() {
      _loading = true;
    });

    final results = await Future.wait([
      _db.getAllExpenses(),
      _db.getAllAccounts(),
    ]);

    final items = results[0] as List<Expense>;
    final accounts = results[1] as List<Account>;
    if (!mounted) {
      return;
    }

    setState(() {
      _expenses = items;
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _reloadExpenses() => _reloadDashboard();

  Future<void> _reloadAccounts() async {
    final accounts = await _db.getAllAccounts();
    if (!mounted) {
      return;
    }

    setState(() {
      _accounts = accounts;
    });
  }

  Future<void> _openAddTransactionSheet() async {
    await _openExpenseEditor();
  }

  Future<void> _openEditTransactionSheet(Expense expense) async {
    await _openExpenseEditor(expense: expense);
  }

  Future<void> _openExpenseEditor({Expense? expense}) async {
    final amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    final categoryController = TextEditingController(
      text: expense?.category ?? 'General',
    );
    final noteController = TextEditingController(text: expense?.notes ?? '');

    String accountType = expense?.accountType ?? kCashAccount;
    String transactionType = expense?.transactionType ?? kExpenseType;

    final shouldSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return _AddTransactionPage(
            expense: expense,
            availableAccounts: _accounts,
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

    final updatedExpense = Expense(
      id: expense?.id,
      amount: amount,
      currency: expense?.currency ?? 'USD',
      date: expense?.date ?? DateTime.now(),
      category: categoryController.text.trim().isEmpty
          ? 'General'
          : categoryController.text.trim(),
      accountType: accountType,
      transactionType: transactionType,
      notes: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
      receiptPath: expense?.receiptPath,
    );

    if (expense == null) {
      await _db.insertExpense(updatedExpense);
    } else {
      await _db.updateExpense(updatedExpense);
    }

    await _reloadExpenses();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTab = 0;
    });
  }

  Future<void> _openAddAccountSheet() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const _AddAccountPage(),
      ),
    );

    if (result is! Account) {
      return;
    }

    await _db.insertAccount(result);
    await _reloadAccounts();
  }

  Future<void> _openEditAccountSheet(Account account) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _AddAccountPage(account: account),
      ),
    );

    if (result is _AccountEditorResult && result.deleted) {
      if (result.account?.id != null) {
        await _db.deleteAccount(result.account!.id!);
        await _reloadAccounts();
      }
      return;
    }

    if (result is! Account) {
      return;
    }

    await _db.updateAccount(result);
    await _reloadAccounts();
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
        onEdit: _openEditTransactionSheet,
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
        customAccounts: _accounts,
        cashBalance: _cashBalance,
        bankBalance: _bankBalance,
        onAddAccount: _openAddAccountSheet,
        onEditAccount: _openEditAccountSheet,
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
    required this.onEdit,
  });

  final bool loading;
  final List<Expense> expenses;
  final double incomeTotal;
  final double expenseTotal;
  final double netTotal;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Expense expense) onDelete;
  final Future<void> Function(Expense expense) onEdit;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int? _selectedYear;
  int? _selectedMonth;

  static const List<String> _monthNames = <String>[
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

  List<int> get _availableYears {
    return List<int>.generate(25, (index) => 2026 + index)
      ..sort((left, right) => right.compareTo(left));
  }

  bool get _hasCustomDateFilter => _selectedYear != null;

  List<Expense> get _filteredExpenses {
    if (_selectedYear != null) {
      return widget.expenses.where((expense) {
        if (expense.date.year != _selectedYear) {
          return false;
        }

        if (_selectedMonth != null && expense.date.month != _selectedMonth) {
          return false;
        }

        return true;
      }).toList();
    }

    return widget.expenses;
  }

  String _activePeriodLabel() {
    if (_selectedYear != null) {
      if (_selectedMonth != null) {
        return '${_monthNames[_selectedMonth! - 1]} $_selectedYear';
      }

      return '$_selectedYear';
    }

    return 'All transactions';
  }

  void _clearCustomDateFilter() {
    setState(() {
      _selectedYear = null;
      _selectedMonth = null;
    });
  }

  Future<void> _openFilterSheet() async {
    final now = DateTime.now();
    final years = List<int>.from(_availableYears);
    if (_selectedYear != null && !years.contains(_selectedYear)) {
      years.add(_selectedYear!);
      years.sort((left, right) => right.compareTo(left));
    }

    var selectedYear = _selectedYear ?? now.year;
    int? selectedMonth = _selectedMonth;
    var selectedMonthIndex = selectedMonth ?? now.month;
    final selectedYearIndex = years.indexOf(selectedYear);

    final yearController = FixedExtentScrollController(
      initialItem: selectedYearIndex < 0 ? 0 : selectedYearIndex,
    );
    final monthController = FixedExtentScrollController(
      initialItem: selectedMonthIndex,
    );

    try {
      final selection = await showModalBottomSheet<_RecordFilterSelection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                decoration: const BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: kBorder,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Filter records',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a year or a specific month.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 220,
                        child: Row(
                          children: [
                            Expanded(
                              child: _PickerColumnShell(
                                child: CupertinoPicker(
                                  scrollController: yearController,
                                  itemExtent: 42,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  selectionOverlay:
                                      const CupertinoPickerDefaultSelectionOverlay(),
                                  onSelectedItemChanged: (index) {
                                    setSheetState(() {
                                      selectedYear = years[index];
                                    });
                                  },
                                  children: years
                                      .map(
                                        (year) => Center(
                                          child: Text(
                                            '$year',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _PickerColumnShell(
                                child: CupertinoPicker(
                                  scrollController: monthController,
                                  itemExtent: 42,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  selectionOverlay:
                                      const CupertinoPickerDefaultSelectionOverlay(),
                                  onSelectedItemChanged: (index) {
                                    setSheetState(() {
                                      selectedMonthIndex = index;
                                      selectedMonth = index == 0 ? null : index;
                                    });
                                  },
                                  children: [
                                    const Center(
                                      child: Text(
                                        'Any',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    ..._monthNames.map(
                                      (month) => Center(
                                        child: Text(
                                          month,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop(
                                  const _RecordFilterSelection(),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kTextPrimary,
                                side: const BorderSide(color: kBorder),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Clear',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop(
                                  _RecordFilterSelection(
                                    year: selectedYear,
                                    month: selectedMonth,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryBlue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Apply',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (!mounted || selection == null) {
        return;
      }

      setState(() {
        _selectedYear = selection.year;
        _selectedMonth = selection.month;
      });
    } finally {
      yearController.dispose();
      monthController.dispose();
    }
  }

  double _sumIncome(List<Expense> list) => list
      .where((expense) => expense.isIncome)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  double _sumExpense(List<Expense> list) => list
      .where((expense) => expense.isExpense)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  @override
  Widget build(BuildContext context) {
    final expenses = _filteredExpenses;
    final incomeTotal = _sumIncome(expenses);
    final expenseTotal = _sumExpense(expenses);
    final netTotal = incomeTotal - expenseTotal;

    return _TabShell(
      title: 'Transactions',
      showFilter: true,
      onFilterPressed: _openFilterSheet,
      filterActive: _hasCustomDateFilter,
      onClearPressed: _clearCustomDateFilter,
      child: widget.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
              children: [
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
                  title: _activePeriodLabel(),
                  action: '${expenses.length} transactions',
                ),
                const SizedBox(height: 8),
                if (expenses.isEmpty)
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
                                onEdit: () => widget.onEdit(expense),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
              ],
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
      showFilter: true,
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
    required this.customAccounts,
    required this.cashBalance,
    required this.bankBalance,
    required this.onAddAccount,
    required this.onEditAccount,
  });

  final bool loading;
  final List<Account> customAccounts;
  final double cashBalance;
  final double bankBalance;
  final VoidCallback onAddAccount;
  final Future<void> Function(Account account) onEditAccount;

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      title: 'Accounts',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Account list',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onAddAccount,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add account'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AccountBalanceCard(
                  title: 'Cash account',
                  amount: cashBalance,
                  icon: Icons.payments_outlined,
                  color: kCashTint,
                ),
                const SizedBox(height: 12),
                _AccountBalanceCard(
                  title: 'Bank account',
                  amount: bankBalance,
                  icon: Icons.account_balance_outlined,
                  color: kBankTint,
                ),
                const SizedBox(height: 12),
                if (customAccounts.isEmpty)
                  const _EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No custom accounts yet',
                    subtitle:
                        'Tap Add account to create savings, wallet, or other balances.',
                  )
                else
                  ...customAccounts.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => onEditAccount(account),
                        child: _AccountBalanceCard(
                          title: account.name,
                          amount: account.balance,
                          icon: Icons.account_balance_wallet_outlined,
                          color: kPrimaryBlue,
                        ),
                      ),
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
      {required this.title,
      required this.child,
      this.showFilter = false,
      this.onFilterPressed,
      this.filterActive = false,
      this.onClearPressed});

  final String title;
  final Widget child;
  final bool showFilter;
  final VoidCallback? onFilterPressed;
  final bool filterActive;
  final VoidCallback? onClearPressed;

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
              _CommonTopBar(
                  title: title,
                  showFilter: showFilter,
                  onFilterPressed: onFilterPressed,
                  filterActive: filterActive,
                  onClearPressed: onClearPressed),
              const SizedBox(height: 16),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommonTopBar extends StatelessWidget {
  const _CommonTopBar(
      {required this.title,
      this.showFilter = false,
      this.onFilterPressed,
      this.filterActive = false,
      this.onClearPressed});

  final String title;
  final bool showFilter;
  final VoidCallback? onFilterPressed;
  final bool filterActive;
  final VoidCallback? onClearPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (showFilter)
              Row(
                children: [
                  if (filterActive)
                    TextButton(
                      onPressed: onClearPressed,
                      style: TextButton.styleFrom(
                        foregroundColor: kTextPrimary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear'),
                    ),
                  IconButton(
                    onPressed: onFilterPressed,
                    icon: const Icon(Icons.filter_alt_rounded,
                        color: kTextPrimary),
                  ),
                ],
              )
            else
              const SizedBox(width: 48),
          ],
        ),
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
        color: kInputBackground,
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
        color: kInputBackground,
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
        color: kInputBackground,
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
        color: kInputBackground,
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
        color: kInputBackground,
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
  const _TransactionCard({required this.expense, this.onDelete, this.onEdit});

  final Expense expense;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final accountColor = expense.accountType == kCashAccount
        ? kCashTint
        : expense.accountType == kBankAccount
            ? kBankTint
            : kPrimaryBlue;
    Color amountColor = expense.isIncome ? kIncomeTint : kExpenseTint;
    String formattedAmount = _formatCurrency(expense.currency, expense.amount);

    return Dismissible(
      key: ValueKey('expense-${expense.id ?? expense.hashCode}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: kIncomeTint.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.edit_rounded, color: kIncomeTint),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: kExpenseTint.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: kExpenseTint),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit?.call();
          return false;
        }

        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        }
        return false;
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
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
        color: kInputBackground,
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
        color: kInputBackground,
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _plainMoney(amount),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: color,
                          ),
                    ),
                  ],
                ),
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
        color: kInputBackground,
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
        color: kInputBackground,
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

class _PickerColumnShell extends StatelessWidget {
  const _PickerColumnShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: kInputBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RecordFilterSelection {
  const _RecordFilterSelection({this.year, this.month});

  final int? year;
  final int? month;
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
          color: kInputBackground,
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
            height: 56,
            width: 56,
            decoration: const BoxDecoration(
              color: kPrimaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
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
    this.expense,
    required this.availableAccounts,
    required this.amountController,
    required this.categoryController,
    required this.noteController,
    required this.accountType,
    required this.transactionType,
    required this.onAccountTypeChanged,
    required this.onTransactionTypeChanged,
  });

  final Expense? expense;
  final List<Account> availableAccounts;
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
  late FocusNode _amountFocusNode;

  @override
  void initState() {
    super.initState();
    _accountType = widget.accountType;
    _transactionType = widget.transactionType;
    _amountFocusNode = FocusNode();

    // Auto-focus the amount field after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    widget.onAccountTypeChanged(_accountType);
    widget.onTransactionTypeChanged(_transactionType);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final accountOptions = <_AccountChoice>[
      const _AccountChoice(
        value: kCashAccount,
        label: 'Cash',
        icon: Icons.payments_outlined,
        color: kCashTint,
      ),
      const _AccountChoice(
        value: kBankAccount,
        label: 'Bank',
        icon: Icons.account_balance_outlined,
        color: kBankTint,
      ),
      ...widget.availableAccounts.map(
        (account) => _AccountChoice(
          value: account.name,
          label: account.name,
          icon: Icons.account_balance_wallet_outlined,
          color: Color(account.colorValue),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kInputBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop())
                Navigator.of(context).pop(false);
            });
          },
          icon: const Icon(Icons.close_rounded, color: kTextPrimary),
        ),
        title: Text(
          widget.expense == null ? 'Transactions' : 'Edit transaction',
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _ModernAddFieldSection(
              title: 'Amount',
              icon: Icons.attach_money_rounded,
              child: TextField(
                controller: widget.amountController,
                focusNode: _amountFocusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: kTextSecondary.withOpacity(0.5),
                    fontSize: 18,
                  ),
                  filled: true,
                  fillColor: kInputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kBorder,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kPrimaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ModernAddFieldSection(
              title: 'Category',
              icon: Icons.category_rounded,
              child: TextField(
                controller: widget.categoryController,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: kTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'General',
                  hintStyle: TextStyle(
                    color: kTextSecondary.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: kInputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kBorder,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kPrimaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ModernToggleSection(
              title: 'Account',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth =
                      (constraints.maxWidth - 12) / 2; // two columns
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: accountOptions
                        .map(
                          (account) => SizedBox(
                            width: tileWidth,
                            child: _CustomToggleButton(
                              label: account.label,
                              icon: account.icon,
                              isSelected: _accountType == account.value,
                              onTap: () {
                                setState(() {
                                  _accountType = account.value;
                                });
                              },
                              color: account.color,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _ModernToggleSection(
              title: 'Transaction type',
              child: Row(
                children: [
                  Expanded(
                    child: _CustomToggleButton(
                      label: 'Expense',
                      icon: Icons.remove_circle_outline,
                      isSelected: _transactionType == kExpenseType,
                      onTap: () {
                        setState(() {
                          _transactionType = kExpenseType;
                        });
                      },
                      color: kExpenseTint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CustomToggleButton(
                      label: 'Income',
                      icon: Icons.add_circle_outline,
                      isSelected: _transactionType == kIncomeType,
                      onTap: () {
                        setState(() {
                          _transactionType = kIncomeType;
                        });
                      },
                      color: kIncomeTint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ModernAddFieldSection(
              title: 'Note',
              icon: Icons.note_rounded,
              child: TextField(
                controller: widget.noteController,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: kTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)',
                  hintStyle: TextStyle(
                    color: kTextSecondary.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: kInputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kBorder,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kPrimaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.expense == null
                      ? 'Save Transaction'
                      : 'Update Transaction',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAccountPage extends StatefulWidget {
  const _AddAccountPage({this.account});

  final Account? account;

  @override
  State<_AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<_AddAccountPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late int _selectedColorValue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(
      text: (widget.account?.balance ?? 0).toStringAsFixed(2),
    );
    _selectedColorValue = widget.account?.colorValue ?? kCashTint.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _close([Object? result]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      }
    });
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This account will be removed from the app. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: kExpenseTint),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && widget.account != null) {
      FocusScope.of(context).unfocus();
      _close(_AccountEditorResult.deleted(widget.account!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.account != null;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kInputBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            _close();
          },
          icon: const Icon(Icons.close_rounded, color: kTextPrimary),
        ),
        title: Text(
          isEditing ? 'Edit account' : 'Add account',
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _ModernAddFieldSection(
              title: 'Account name',
              icon: Icons.account_balance_wallet_outlined,
              child: TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: kTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Savings',
                  hintStyle: TextStyle(
                    color: kTextSecondary.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: kInputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kBorder,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kPrimaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ModernAddFieldSection(
              title: 'Account color',
              icon: Icons.palette_outlined,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kAccountColorOptions
                    .map(
                      (color) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColorValue = color.value;
                          });
                        },
                        child: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColorValue == color.value
                                  ? color
                                  : color.withOpacity(0.28),
                              width: _selectedColorValue == color.value ? 3 : 1,
                            ),
                          ),
                          child: Icon(
                            Icons.circle,
                            size: 18,
                            color: color,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            _ModernAddFieldSection(
              title: 'Starting balance',
              icon: Icons.currency_exchange_rounded,
              child: TextField(
                controller: _balanceController,
                readOnly: isEditing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: kTextSecondary.withOpacity(0.5),
                    fontSize: 18,
                  ),
                  filled: true,
                  fillColor: kInputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kBorder,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: kPrimaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final balance =
                      double.tryParse(_balanceController.text.trim()) ?? 0;
                  if (name.isEmpty) {
                    return;
                  }

                  FocusScope.of(context).unfocus();
                  _close(
                    Account(
                      id: widget.account?.id,
                      name: name,
                      balance: isEditing ? widget.account!.balance : balance,
                      colorValue: _selectedColorValue,
                      createdAt: widget.account?.createdAt,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isEditing ? 'Save changes' : 'Add account',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kExpenseTint,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: kExpenseTint),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Delete account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountEditorResult {
  const _AccountEditorResult._(this.account, this.deleted);

  const _AccountEditorResult.deleted(Account account) : this._(account, true);

  final Account? account;
  final bool deleted;
}

class _AccountChoice {
  const _AccountChoice({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _ModernAddFieldSection extends StatelessWidget {
  const _ModernAddFieldSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: kPrimaryBlue),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    fontSize: 15,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ModernToggleSection extends StatelessWidget {
  const _ModernToggleSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
                fontSize: 15,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _CustomToggleButton extends StatelessWidget {
  const _CustomToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : kInputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : kBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : kTextSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

String _plainMoney(double value) => value.toStringAsFixed(2);

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
