import '../models/currency_option.dart';
import 'app_preferences.dart';

class CurrencyService {
  CurrencyService._();

  static String code = 'USD';

  static CurrencyOption get current => optionForCode(code);

  static CurrencyOption optionForCode(String currencyCode) {
    final normalized = currencyCode.trim().toUpperCase();
    return kCurrencyOptions.firstWhere(
      (option) => option.code == normalized,
      orElse: () => kCurrencyOptions.first,
    );
  }

  static Future<void> load() async {
    code = await AppPreferences.instance.defaultCurrency;
  }

  static Future<void> setCode(String newCode) async {
    code = newCode;
    await AppPreferences.instance.setDefaultCurrency(newCode);
  }

  /// Formats [value] using the user's selected app currency.
  static String format(double value) => formatWithOption(current, value);

  /// Formats [value] for a specific ISO currency [currencyCode].
  static String formatForCode(String currencyCode, double value) {
    return formatWithOption(optionForCode(currencyCode), value);
  }

  static String formatWithOption(CurrencyOption option, double value) {
    final s = value.toStringAsFixed(2);
    final parts = s.split('.');
    final integer = parts[0];
    final fraction = parts.length > 1 ? parts[1] : '00';
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final withCommas = integer.replaceAllMapped(reg, (m) => ',${m.group(0)}');

    switch (option.code) {
      case 'INR':
      case 'LKR':
        return '${option.symbol} $withCommas.$fraction';
      case 'EUR':
        return '${option.symbol}$withCommas.$fraction';
      default:
        return '${option.symbol}$withCommas.$fraction';
    }
  }
}
