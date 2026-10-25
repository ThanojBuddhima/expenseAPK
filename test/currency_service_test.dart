import 'package:flutter_test/flutter_test.dart';

import 'package:expence_apk/models/currency_option.dart';
import 'package:expence_apk/services/currency_service.dart';

void main() {
  test('includes a broad list of unique current currencies', () {
    final codes = kCurrencyOptions.map((option) => option.code).toSet();

    expect(kCurrencyOptions.length, greaterThan(140));
    expect(codes.length, kCurrencyOptions.length);
    expect(codes, containsAll(['USD', 'LKR', 'EUR', 'JPY', 'BHD']));
  });

  test('formats currencies using their configured decimal precision', () {
    expect(
      CurrencyService.formatWithOption(
        CurrencyService.optionForCode('USD'),
        1234.56,
      ),
      r'$1,234.56',
    );
    expect(
      CurrencyService.formatWithOption(
        CurrencyService.optionForCode('JPY'),
        1234.56,
      ),
      '¥1,235',
    );
    expect(
      CurrencyService.formatWithOption(
        CurrencyService.optionForCode('BHD'),
        1234.567,
      ),
      'BHD1,234.567',
    );
    expect(
      CurrencyService.formatWithOption(
        CurrencyService.optionForCode('LKR'),
        1234.5,
      ),
      'Rs. 1,234.50',
    );
  });
}
