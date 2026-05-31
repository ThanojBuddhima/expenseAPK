import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/db_service.dart';
import 'auth_lock_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.buildDashboard,
  });

  final Widget Function() buildDashboard;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) {
      return;
    }

    await CurrencyService.load();

    var showOnboarding = await AppPreferences.instance.shouldShowOnboarding();
    if (showOnboarding) {
      final expenses = await DBService.instance.getAllExpenses();
      final accounts = await DBService.instance.getAllAccounts();
      if (expenses.isNotEmpty || accounts.isNotEmpty) {
        await AppPreferences.instance.setOnboardingComplete(true);
        showOnboarding = false;
      }
    }

    if (!mounted) {
      return;
    }

    if (showOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(buildDashboard: widget.buildDashboard),
        ),
      );
      return;
    }

    final needsLock = await AuthService.instance.requiresUnlock();
    if (!mounted) {
      return;
    }

    final next = needsLock
        ? AuthLockScreen(buildDashboard: widget.buildDashboard)
        : widget.buildDashboard();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Expensely',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Offline-first • Private • Secure',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
