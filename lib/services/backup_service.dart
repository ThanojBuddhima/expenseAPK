import 'dart:convert';
import 'dart:io';

import '../models/expense.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  Future<File> exportExpenses(
      List<Expense> expenses, Directory targetDir) async {
    final file = File('${targetDir.path}/expenses_export.json');
    final json = jsonEncode(expenses.map((e) => e.toMap()).toList());
    return await file.writeAsString(json);
  }

  Future<List<Expense>> importFromFile(File file) async {
    final content = await file.readAsString();
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded
        .map((m) => Expense.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }
}
