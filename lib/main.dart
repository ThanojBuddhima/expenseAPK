import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models/account.dart';
import 'models/budget.dart';
import 'models/category.dart';
import 'models/expense.dart';
import 'models/time_period.dart';
import 'screens/auth_lock_screen.dart';
import 'screens/budgets_tab.dart';
import 'screens/categories_tab.dart';
import 'screens/calculator_tab.dart';
import 'screens/settings_tab.dart';
import 'screens/splash_screen.dart';
import 'services/app_preferences.dart';
import 'services/auth_service.dart';
import 'services/currency_service.dart';
import 'services/db_service.dart';
import 'services/account_balance.dart';
import 'widgets/bottom_add_button.dart';
import 'widgets/frosted_bar.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/outlined_choice_button.dart';
import 'widgets/period_navigator_bar.dart';
import 'widgets/spending_trend_chart.dart';

const String kCashAccount = 'cash';
const String kIncomeType = 'income';
const String kExpenseType = 'expense';
const List<String> kIncomeCategories = [
  'Salary',
  'Bonus',
  'Allowance',
  'Other',
];
const String kDefaultIncomeCategory = 'Salary';
const Color kPrimaryBlue = AppColors.primary;
const Color kPrimaryBlueDeep = AppColors.primaryDeep;
const Color kSurface = AppColors.surface;
const Color kTextPrimary = AppColors.textPrimary;
const Color kTextSecondary = AppColors.textSecondary;
const Color kBorder = AppColors.border;
const Color kCashTint = AppColors.cashTint;
const Color kBankTint = AppColors.cashTint;
const Color kIncomeTint = AppColors.incomeTint;
const Color kExpenseTint = AppColors.expenseTint;
const Color kInputBackground = AppColors.inputBackground;
const List<Color> kAccountColorOptions = [
  AppColors.primary,
  AppColors.incomeTint,
  AppColors.expenseTint,
  AppColors.pastelPink,
  AppColors.pastelYellow,
  AppColors.pastelLavender,
  AppColors.pastelOrange,
  AppColors.darkBanner,
];

String _accountDisplayName(String accountType) =>
    accountType == kCashAccount ? 'Cash' : accountType;

Color _accountColorFor(String accountType, List<Account> accounts) {
  if (accountType == kCashAccount) {
    return kCashTint;
  }
  for (final account in accounts) {
    if (account.name == accountType) {
      return Color(account.colorValue);
    }
  }
  return kCashTint;
}

enum FilterMode { day, week, month, annually }

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.instance.init();
  await DBService.instance.init();
  await CurrencyService.load();
  runApp(const ExpenseApp());
}

void main() {
  initializeApp();
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({super.key});

  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  bool _showLockOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lockSessionIfNeeded();
    } else if (state == AppLifecycleState.resumed) {
      _showLockIfNeeded();
    }
  }

  Future<void> _lockSessionIfNeeded() async {
    if (await AuthService.instance.shouldLockOnBackground()) {
      AuthService.instance.lockSession();
    }
  }

  Future<void> _showLockIfNeeded() async {
    if (!AuthService.instance.isSessionLocked || !mounted) {
      return;
    }
    setState(() => _showLockOverlay = true);
  }

  Future<void> _loadTheme() async {
    final mode = await AppPreferences.instance.themeMode;
    if (mounted) {
      setState(() => _themeMode = mode);
    }
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    AppPreferences.instance.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expensely',
      scrollBehavior: const _NoScrollbarBehavior(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (_showLockOverlay)
              Positioned.fill(
                child: AuthLockScreen(
                  onUnlocked: () {
                    setState(() => _showLockOverlay = false);
                  },
                ),
              ),
          ],
        );
      },
      home: SplashScreen(
        buildDashboard: () => ExpenseDashboardPage(
          onThemeChanged: setThemeMode,
        ),
      ),
    );
  }
}

class ExpenseDashboardPage extends StatefulWidget {
  const ExpenseDashboardPage({super.key, required this.onThemeChanged});

  final ValueChanged<ThemeMode> onThemeChanged;

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
  List<ExpenseCategory> _categories = <ExpenseCategory>[];
  List<Budget> _budgets = <Budget>[];
  bool _loading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _reloadDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesSilently();
    });
  }

  Future<void> _checkForUpdatesSilently() async {
    if (!mounted) {
      return;
    }
    await checkAndPromptForUpdate(context, silentIfLatest: true);
  }

  Future<void> _reloadDashboard() async {
    await CurrencyService.load();
    setState(() {
      _loading = true;
    });

    final results = await Future.wait([
      _db.getAllExpenses(),
      _db.getAllAccounts(),
      _db.getAllCategories(),
      _db.getAllBudgets(),
    ]);

    final items = results[0] as List<Expense>;
    final accounts = results[1] as List<Account>;
    final categories = results[2] as List<ExpenseCategory>;
    final budgets = results[3] as List<Budget>;
    if (!mounted) {
      return;
    }

    setState(() {
      _expenses = items;
      _accounts = accounts;
      _categories = categories;
      _budgets = budgets;
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

  Future<void> _openCategoriesPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Categories')),
          body: CategoriesTab(onChanged: _reloadDashboard),
        ),
      ),
    );
    await _reloadDashboard();
  }

  Future<void> _openBudgetsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Budgets')),
          body: BudgetsTab(onChanged: _reloadDashboard),
        ),
      ),
    );
    await _reloadDashboard();
  }

  Future<void> _openAccountsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _AccountsManagePage(
          onAddAccount: _openAddAccountSheet,
          onEditAccount: _openEditAccountSheet,
        ),
      ),
    );
    await _reloadAccounts();
  }

  Future<void> _openExpenseEditor({Expense? expense}) async {
    final result = await Navigator.of(context).push<_ExpenseEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return _AddTransactionPage(
            expense: expense,
            availableAccounts: _accounts,
            categories: _categories,
          );
        },
      ),
    );

    if (result == null) {
      return;
    }

    if (result.deleted) {
      if (expense?.id != null) {
        await _db.deleteExpense(expense!.id!);
        await _reloadExpenses();
      }
      return;
    }

    if (!result.saved) {
      return;
    }

    final amount = double.tryParse(result.amountText);
    if (amount == null || amount <= 0) {
      return;
    }

    final categoryText = result.categoryText;
    final updatedExpense = Expense(
      id: expense?.id,
      title: result.titleText.isEmpty ? categoryText : result.titleText,
      amount: amount,
      currency: expense?.currency ?? CurrencyService.code,
      date: expense?.date ?? DateTime.now(),
      category: categoryText.isEmpty ? 'General' : categoryText,
      accountType: result.accountType,
      transactionType: result.transactionType,
      notes: result.noteText.isEmpty ? null : result.noteText,
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
        categories: _categories,
        accounts: _accounts,
        budgets: _budgets,
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
      CalculatorTab(),
      SettingsTab(
        onThemeChanged: widget.onThemeChanged,
        onAccountsTap: _openAccountsPage,
        onCategoriesTap: _openCategoriesPage,
        onBudgetsTap: _openBudgetsPage,
        onCurrencyChanged: () => setState(() {}),
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedTab, children: pages),
      bottomNavigationBar: Material(
        color: Colors.transparent,
        child: _BottomNavBar(
          selectedIndex: _selectedTab,
          onAdd: _openAddTransactionSheet,
          onTap: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.loading,
    required this.expenses,
    required this.categories,
    required this.accounts,
    required this.budgets,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.netTotal,
    required this.onRefresh,
    required this.onDelete,
    required this.onEdit,
  });

  final bool loading;
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final List<Account> accounts;
  final List<Budget> budgets;
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
  TimePeriod _period = TimePeriod.currentMonth();
  String? _selectedCategory;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Expense> get _filteredExpenses {
    final query = _searchQuery.trim().toLowerCase();
    return widget.expenses.where((expense) {
      if (!_period.contains(expense.date)) {
        return false;
      }
      if (_selectedCategory != null && expense.category != _selectedCategory) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack =
            '${expense.displayTitle} ${expense.category} ${expense.notes ?? ''}'
                .toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Budget? get _currentOverallBudget {
    final now = DateTime.now();
    for (final budget in widget.budgets) {
      if (budget.isOverall &&
          budget.year == now.year &&
          budget.month == now.month) {
        return budget;
      }
    }
    return null;
  }

  double get _currentMonthExpenses {
    final now = DateTime.now();
    return widget.expenses
        .where((e) =>
            e.isExpense && e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0, (sum, e) => sum + e.amount);
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
    final budget = _currentOverallBudget;
    final monthSpend = _currentMonthExpenses;

    return _TabShell(
      child: widget.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
              children: [
                PeriodNavigatorBar(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search expenses...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                    ),
                  ),
                ),
                if (widget.categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedChoiceButton(
                            label: 'All',
                            color: kPrimaryBlue,
                            isSelected: _selectedCategory == null,
                            compact: true,
                            onTap: () =>
                                setState(() => _selectedCategory = null),
                          ),
                        ),
                        ...widget.categories.map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedChoiceButton(
                              label: category.name,
                              color: kTextPrimary,
                              isSelected:
                                  _selectedCategory == category.name,
                              compact: true,
                              onTap: () => setState(
                                () => _selectedCategory = category.name,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SummaryStrip(
                  leftLabel: 'Income',
                  leftValue: _money(incomeTotal),
                  middleLabel: 'Expenses',
                  middleValue: _money(expenseTotal),
                  rightLabel: 'Total',
                  rightValue: _money(netTotal),
                ),
                if (budget != null) ...[
                  const SizedBox(height: 12),
                  _BudgetProgressCard(
                    spent: monthSpend,
                    limit: budget.amount,
                  ),
                ],
                const SizedBox(height: 12),
                _SectionHeader(
                  title: 'Transactions',
                  action: '${expenses.length} items',
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
                                accounts: widget.accounts,
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

class _StatsTab extends StatefulWidget {
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
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  bool _showExpense = true;
  TimePeriod _period = TimePeriod.currentMonth();

  List<Expense> get _filteredExpenses {
    return widget.expenses
        .where((expense) => _period.contains(expense.date))
        .toList();
  }

  List<Expense> get _selectedCategoryExpenses {
    return _filteredExpenses.where((expense) {
      return (_showExpense && expense.isExpense) ||
          (!_showExpense && expense.isIncome);
    }).toList();
  }

  Map<String, double> get _selectedCategoryTotals {
    final totals = <String, double>{};
    for (final expense in _selectedCategoryExpenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  List<MapEntry<String, double>> get _sortedCategoryEntries {
    final entries = _selectedCategoryTotals.entries.toList();
    entries.sort((left, right) => right.value.compareTo(left.value));
    return entries;
  }

  double get _selectedTotal =>
      _selectedCategoryTotals.values.fold(0, (sum, value) => sum + value);

  double _sumIncome(List<Expense> list) => list
      .where((expense) => expense.isIncome)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  double _sumExpense(List<Expense> list) => list
      .where((expense) => expense.isExpense)
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _filteredExpenses;
    final incomeTotal = _sumIncome(filteredExpenses);
    final expenseTotal = _sumExpense(filteredExpenses);

    return _TabShell(
      child: widget.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
              children: [
                PeriodNavigatorBar(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedChoiceButton(
                          label: 'Income',
                          subtitle: _money(incomeTotal),
                          isSelected: !_showExpense,
                          color: kIncomeTint,
                          onTap: () => setState(() => _showExpense = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedChoiceButton(
                          label: 'Expenses',
                          subtitle: _money(expenseTotal),
                          isSelected: _showExpense,
                          color: kExpenseTint,
                          onTap: () => setState(() => _showExpense = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _PieCard(categoryTotals: _selectedCategoryTotals),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _SectionHeader(
                    title: 'Spending trend',
                    action: _period.displayLabel,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SpendingTrendChart(
                      expenses: filteredExpenses,
                      showExpense: _showExpense,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _SectionHeader(
                    title: 'Category breakdown',
                    action: '${filteredExpenses.length} items',
                  ),
                ),
                const SizedBox(height: 12),
                if (_sortedCategoryEntries.isEmpty)
                  const _EmptyState(
                    icon: Icons.pie_chart_outline,
                    title: 'No data yet',
                    subtitle: 'Add transactions to see category breakdowns.',
                  )
                else
                  ..._sortedCategoryEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value.key;
                    final amount = entry.value.value;
                    final percent = _selectedTotal > 0
                        ? amount / _selectedTotal * 100
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: _CategoryBreakdownListItem(
                        category: category,
                        amount: _money(amount),
                        percent: percent,
                        color: index == 5
                            ? const Color(0xFF64748B)
                            : _chartColor(index),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _CategoryBreakdownListItem extends StatelessWidget {
  const _CategoryBreakdownListItem({
    required this.category,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String category;
  final String amount;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              category,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(amount,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AccountsManagePage extends StatefulWidget {
  const _AccountsManagePage({
    required this.onAddAccount,
    required this.onEditAccount,
  });

  final Future<void> Function() onAddAccount;
  final Future<void> Function(Account account) onEditAccount;

  @override
  State<_AccountsManagePage> createState() => _AccountsManagePageState();
}

class _AccountsManagePageState extends State<_AccountsManagePage> {
  bool _loading = true;
  List<Account> _accounts = [];
  Map<String, double> _accountBalances = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DBService.instance;
    final results = await Future.wait([
      db.getAllAccounts(),
      db.getAllExpenses(),
    ]);
    final accounts = results[0] as List<Account>;
    final expenses = results[1] as List<Expense>;
    final balances = balancesForAllAccounts(
      expenses,
      accounts.map((account) => account.name).toList(),
    );
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _accountBalances = balances;
        _loading = false;
      });
    }
  }

  Future<void> _handleAdd() async {
    await widget.onAddAccount();
    await _load();
  }

  Future<void> _handleEdit(Account account) async {
    await widget.onEditAccount(account);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: _AccountsTab(
        loading: _loading,
        customAccounts: _accounts,
        accountBalances: _accountBalances,
        onAddAccount: _handleAdd,
        onEditAccount: _handleEdit,
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({
    required this.loading,
    required this.customAccounts,
    required this.accountBalances,
    required this.onAddAccount,
    required this.onEditAccount,
  });

  final bool loading;
  final List<Account> customAccounts;
  final Map<String, double> accountBalances;
  final Future<void> Function() onAddAccount;
  final Future<void> Function(Account account) onEditAccount;

  double _balanceFor(String accountKey) => accountBalances[accountKey] ?? 0;

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ManageListScaffold(
              addLabel: 'Add account',
              onAdd: onAddAccount,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Account list',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _AccountBalanceCard(
                  title: 'Cash account',
                  amount: _balanceFor(kCashAccount),
                  icon: Icons.payments_outlined,
                  color: kCashTint,
                ),
                const SizedBox(height: 12),
                if (customAccounts.isEmpty)
                  const _EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No custom accounts yet',
                    subtitle:
                        'Create an account to track savings, wallet, or other balances.',
                  )
                else
                  ...customAccounts.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => onEditAccount(account),
                        child: _AccountBalanceCard(
                          title: account.name,
                          amount: _balanceFor(account.name),
                          icon: Icons.account_balance_wallet_outlined,
                          color: Color(account.colorValue),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({required this.spent, required this.limit});

  final double spent;
  final double limit;

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final overBudget = spent > limit;
    final palette = context.palette;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly budget',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: palette.border,
                color: overBudget ? kExpenseTint : kPrimaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_money(spent)} of ${_money(limit)} used this month',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabShell extends StatelessWidget {
  const _TabShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TopFadeOverlay(child: child);
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
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryChip(
              label: leftLabel,
              value: leftValue,
              color: kIncomeTint,
            ),
          ),
          Expanded(
            child: _SummaryChip(
              label: middleLabel,
              value: middleValue,
              color: kExpenseTint,
            ),
          ),
          Expanded(
            child: _SummaryChip(
              label: rightLabel,
              value: rightValue,
              color: kPrimaryBlue,
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
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
          ),
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
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.input,
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

    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
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
              painter: _PieChartPainter(
                segments,
                holeColor: context.palette.card,
              ),
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
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
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
  const _PieChartPainter(this.segments, {required this.holeColor});

  final List<_PieSegment> segments;
  final Color holeColor;

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
      Paint()..color = holeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.holeColor != holeColor;
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.expense,
    required this.accounts,
    this.onDelete,
    this.onEdit,
  });

  final Expense expense;
  final List<Account> accounts;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accountColor = _accountColorFor(expense.accountType, accounts);
    final accountLabel = _accountDisplayName(expense.accountType);
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
          final edit = onEdit;
          if (edit != null) {
            Future<void>.delayed(Duration.zero, edit);
          }
          return false;
        }

        if (direction == DismissDirection.endToStart) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete transaction?'),
              content: Text(
                'Remove "${expense.displayTitle}" ($formattedAmount)? '
                'This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: TextButton.styleFrom(foregroundColor: kExpenseTint),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            onDelete?.call();
          }
        }
        return false;
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                            ?.copyWith(color: palette.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expense.displayTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        accountLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: palette.textSecondary, fontSize: 12),
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
                            accountLabel,
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
    final palette = context.palette;
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
        color: palette.input,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: palette.card,
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
                        color: palette.textSecondary,
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
        color: context.palette.input,
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
        color: context.palette.input,
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
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: palette.emptyIconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: palette.emptyIconFg),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
          ),
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
    final palette = context.palette;
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
                ?.copyWith(color: palette.textSecondary),
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
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.card.withValues(alpha: isDark ? 0.78 : 0.9),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: isDark ? 0.1 : 0.06),
                  ),
                ),
                child: SizedBox(
                  height: 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _NavItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        active: selectedIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      _NavItem(
                        icon: Icons.pie_chart_rounded,
                        label: 'Analytics',
                        active: selectedIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      _AddNavItem(onTap: onAdd),
                      _NavItem(
                        icon: Icons.calculate_rounded,
                        label: 'Calculator',
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
            ),
          ),
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
    final palette = context.palette;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: active ? kPrimaryBlue : palette.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? kPrimaryBlue : palette.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseEditorResult {
  const _ExpenseEditorResult({
    required this.saved,
    this.deleted = false,
    this.amountText = '',
    this.titleText = '',
    this.categoryText = '',
    this.noteText = '',
    this.accountType = kCashAccount,
    this.transactionType = kExpenseType,
  });

  const _ExpenseEditorResult.deleted()
      : saved = false,
        deleted = true,
        amountText = '',
        titleText = '',
        categoryText = '',
        noteText = '',
        accountType = kCashAccount,
        transactionType = kExpenseType;

  final bool saved;
  final bool deleted;
  final String amountText;
  final String titleText;
  final String categoryText;
  final String noteText;
  final String accountType;
  final String transactionType;
}

class _AddTransactionPage extends StatefulWidget {
  const _AddTransactionPage({
    this.expense,
    required this.availableAccounts,
    required this.categories,
  });

  final Expense? expense;
  final List<Account> availableAccounts;
  final List<ExpenseCategory> categories;

  @override
  State<_AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<_AddTransactionPage> {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late String _accountType;
  late String _transactionType;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    _titleController = TextEditingController(
      text: expense?.displayTitle ?? '',
    );
    _categoryController = TextEditingController(
      text: expense?.category ?? '',
    );
    _noteController = TextEditingController(text: expense?.notes ?? '');
    _transactionType = expense?.transactionType ?? kExpenseType;
    _accountType = expense?.accountType ?? _defaultAccountType();
    _selectedCategory = expense?.category ?? _defaultCategory();
  }

  List<String> get _categoryOptions {
    if (_transactionType == kIncomeType) {
      return kIncomeCategories;
    }
    if (widget.categories.isEmpty) {
      return const ['Other'];
    }
    final names = widget.categories.map((category) => category.name).toList();
    if (!names.contains('Other')) {
      names.add('Other');
    }
    return names;
  }

  List<_AccountChoice> get _accountChoices => [
        const _AccountChoice(
          value: kCashAccount,
          label: 'Cash',
          icon: Icons.payments_outlined,
          color: kCashTint,
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

  String _defaultAccountType() {
    final options = _accountChoices;
    return options.length == 1 ? options.first.value : '';
  }

  String _defaultCategory() {
    final options = _categoryOptions;
    return options.length == 1 ? options.first : '';
  }

  void _setTransactionType(String type) {
    setState(() {
      _transactionType = type;
      if (widget.expense == null) {
        _selectedCategory = _defaultCategory();
      } else if (type == kIncomeType) {
        if (!kIncomeCategories.contains(_selectedCategory)) {
          _selectedCategory = '';
        }
      } else if (kIncomeCategories.contains(_selectedCategory)) {
        _selectedCategory = '';
      } else if (!_categoryOptions.contains(_selectedCategory)) {
        _selectedCategory = '';
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _close([bool saved = false]) {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      saved
          ? _ExpenseEditorResult(
              saved: true,
              amountText: _amountController.text.trim(),
              titleText: _titleController.text.trim(),
              categoryText: _selectedCategory.trim().isEmpty
                  ? _categoryController.text.trim()
                  : _selectedCategory.trim(),
              noteText: _noteController.text.trim(),
              accountType: _accountType,
              transactionType: _transactionType,
            )
          : const _ExpenseEditorResult(saved: false),
    );
  }

  void _save() {
    if (_accountType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }
    if (_categoryOptions.isNotEmpty && _selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    _close(true);
  }

  Future<void> _confirmDelete() async {
    final expense = widget.expense;
    if (expense == null) {
      return;
    }

    final formattedAmount = CurrencyService.format(expense.amount);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          'Remove "${expense.displayTitle}" ($formattedAmount)? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: kExpenseTint),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    Navigator.of(context).pop(const _ExpenseEditorResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final palette = context.palette;
    final accountOptions = _accountChoices;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => _close(false),
          icon: Icon(Icons.close_rounded, color: palette.textPrimary),
        ),
        title: Text(
          widget.expense == null
              ? (_transactionType == kIncomeType ? 'Add income' : 'Add expense')
              : (_transactionType == kIncomeType ? 'Edit income' : 'Edit expense'),
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, AppTheme.screenTopPadding, 20, 32 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _ModernToggleSection(
              title: 'Transaction type',
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedChoiceButton(
                      label: 'Expense',
                      icon: Icons.remove_circle_outline,
                      isSelected: _transactionType == kExpenseType,
                      onTap: () => _setTransactionType(kExpenseType),
                      color: kExpenseTint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedChoiceButton(
                      label: 'Income',
                      icon: Icons.add_circle_outline,
                      isSelected: _transactionType == kIncomeType,
                      onTap: () => _setTransactionType(kIncomeType),
                      color: kIncomeTint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ModernAddFieldSection(
              title: 'Title',
              icon: Icons.title_rounded,
              child: TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
                decoration: _themedInputDecoration(
                  context,
                  hintText: 'Coffee, groceries, salary...',
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ModernAddFieldSection(
              title: 'Amount',
              icon: Icons.attach_money_rounded,
              child: TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
                decoration: _themedInputDecoration(
                  context,
                  hintText: '0.00',
                  hintFontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ModernToggleSection(
              title: 'Category',
              child: _categoryOptions.isEmpty
                  ? TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(hintText: 'General'),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final tileWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _categoryOptions.map((name) {
                            return SizedBox(
                              width: tileWidth,
                              child: OutlinedChoiceButton(
                                label: name,
                                isSelected: _selectedCategory == name,
                                onTap: () {
                                  setState(() => _selectedCategory = name);
                                },
                                color: kTextPrimary,
                              ),
                            );
                          }).toList(),
                        );
                      },
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
                            child: OutlinedChoiceButton(
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
            _ModernAddFieldSection(
              title: 'Note',
              icon: Icons.note_rounded,
              child: TextField(
                controller: _noteController,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
                decoration: _themedInputDecoration(
                  context,
                  hintText: 'Add a note (optional)',
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(
                  widget.expense == null
                      ? 'Save Transaction'
                      : 'Update Transaction',
                ),
              ),
            ),
            if (widget.expense != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kExpenseTint,
                    side: const BorderSide(color: kExpenseTint, width: 1.5),
                  ),
                  child: const Text('Delete transaction'),
                ),
              ),
            ],
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
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
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

    if (!mounted) {
      return;
    }

    if (shouldDelete == true && widget.account != null) {
      _close(_AccountEditorResult.deleted(widget.account!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.account != null;
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _close,
          icon: Icon(Icons.close_rounded, color: palette.textPrimary),
        ),
        title: Text(
          isEditing ? 'Edit account' : 'Add account',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, AppTheme.screenTopPadding, 20, 32 + bottomInset),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
                decoration: _themedInputDecoration(context, hintText: 'Savings'),
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
                            color: palette.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColorValue == color.value
                                  ? color
                                  : palette.border,
                              width:
                                  _selectedColorValue == color.value ? 2 : 1,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
                decoration: _themedInputDecoration(
                  context,
                  hintText: '0.00',
                  hintFontSize: 18,
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an account name')),
                    );
                    return;
                  }

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
                child: Text(isEditing ? 'Save changes' : 'Add account'),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _confirmDelete,
                  child: const Text('Delete account'),
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
    final palette = context.palette;
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
                    color: palette.textPrimary,
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
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
                fontSize: 15,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

String _money(double value) => CurrencyService.format(value);

InputDecoration _themedInputDecoration(
  BuildContext context, {
  required String hintText,
  double hintFontSize = 16,
}) {
  final palette = context.palette;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: palette.textSecondary.withValues(alpha: 0.5),
      fontSize: hintFontSize,
    ),
    filled: true,
    fillColor: palette.input,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: palette.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
    ),
  );
}

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
  return AppColors.chartPalette[index % AppColors.chartPalette.length];
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
