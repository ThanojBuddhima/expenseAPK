class Account {
  final int? id;
  final String name;
  final double balance;
  final int colorValue;
  final DateTime createdAt;

  Account({
    this.id,
    required this.name,
    required this.balance,
    required this.colorValue,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'color': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Account',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      colorValue: (map['color'] as int?) ?? 0xFF374151,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
