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
      orElse: () =>
          kCurrencyOptions.firstWhere((option) => option.code == 'USD'),
    );
  }

  static Future<void> load() async {
    code = await AppPreferences.instance.defaultCurrency;
  }

  static Future<void> setCode(String newCode) async {
    final normalized = newCode.trim().toUpperCase();
    if (!kCurrencyOptions.any((option) => option.code == normalized)) {
      throw ArgumentError.value(newCode, 'newCode', 'Unsupported currency');
    }
    code = normalized;
    await AppPreferences.instance.setDefaultCurrency(normalized);
  }

  /// Formats [value] using the user's selected app currency.
  static String format(double value) => formatWithOption(current, value);

  /// Formats [value] for a specific ISO currency [currencyCode].
  static String formatForCode(String currencyCode, double value) {
    return formatWithOption(optionForCode(currencyCode), value);
  }

  static String formatWithOption(CurrencyOption option, double value) {
    final s = value.toStringAsFixed(option.decimalDigits);
    final parts = s.split('.');
    final integer = parts[0];
    final fraction = parts.length > 1 ? '.${parts[1]}' : '';
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final withCommas = integer.replaceAllMapped(reg, (m) => ',${m.group(0)}');

    final prefix = option.code == 'INR' || option.code == 'LKR'
        ? '${option.symbol} '
        : option.symbol;
    return '$prefix$withCommas$fraction';
  }
}
