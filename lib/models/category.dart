class ExpenseCategory {
  final int? id;
  final String name;
  final int colorValue;

  ExpenseCategory({
    this.id,
    required this.name,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': colorValue,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'General',
      colorValue: (map['color'] as int?) ?? 0xFF374151,
    );
  }
}
