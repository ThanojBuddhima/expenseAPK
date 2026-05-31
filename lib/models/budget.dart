class Budget {
  final int? id;
  final String categoryName;
  final double amount;
  final int year;
  final int month;

  Budget({
    this.id,
    required this.categoryName,
    required this.amount,
    required this.year,
    required this.month,
  });

  bool get isOverall => categoryName.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryName': categoryName,
      'amount': amount,
      'year': year,
      'month': month,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      categoryName: (map['categoryName'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      year: (map['year'] as int?) ?? DateTime.now().year,
      month: (map['month'] as int?) ?? DateTime.now().month,
    );
  }
}
