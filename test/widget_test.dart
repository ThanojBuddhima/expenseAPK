import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expence_apk/main.dart' as app;

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const app.MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(app.ExpenseDashboardPage), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
    expect(find.byIcon(Icons.filter_alt_rounded), findsWidgets);
    expect(find.text('Transactions'), findsWidgets);
  });
}
