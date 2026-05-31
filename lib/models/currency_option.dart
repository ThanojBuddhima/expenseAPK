class CurrencyOption {
  const CurrencyOption({
    required this.country,
    required this.code,
    required this.symbol,
  });

  final String country;
  final String code;
  final String symbol;

  String get label => '$country ($code)';
}

const List<CurrencyOption> kCurrencyOptions = [
  CurrencyOption(country: 'United States', code: 'USD', symbol: r'$'),
  CurrencyOption(country: 'United Kingdom', code: 'GBP', symbol: '£'),
  CurrencyOption(country: 'European Union', code: 'EUR', symbol: '€'),
  CurrencyOption(country: 'India', code: 'INR', symbol: 'Rs.'),
  CurrencyOption(country: 'Sri Lanka', code: 'LKR', symbol: 'Rs.'),
  CurrencyOption(country: 'Australia', code: 'AUD', symbol: r'A$'),
  CurrencyOption(country: 'Canada', code: 'CAD', symbol: r'C$'),
  CurrencyOption(country: 'Japan', code: 'JPY', symbol: '¥'),
  CurrencyOption(country: 'Singapore', code: 'SGD', symbol: r'S$'),
  CurrencyOption(country: 'United Arab Emirates', code: 'AED', symbol: 'AED '),
];
