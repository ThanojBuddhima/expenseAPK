import '../models/currency_option.dart';
import 'app_preferences.dart';

class CurrencyService {
  CurrencyService._();

  static String code = 'USD';

  static CurrencyOption get current => kCurrencyOptions.firstWhere(
        (option) => option.code == code,
        orElse: () => kCurrencyOptions.first,
      );

  static Future<void> load() async {
    code = await AppPreferences.instance.defaultCurrency;
  }

  static Future<void> setCode(String newCode) async {
    code = newCode;
    await AppPreferences.instance.setDefaultCurrency(newCode);
  }

  static String format(double value) {
    final option = current;
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
