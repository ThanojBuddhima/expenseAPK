import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expence_apk/main.dart' as app;

void main() {
  testWidgets('Dashboard loads', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: app.ExpenseDashboardPage(onThemeChanged: (_) {}),
      ),
    );
    await tester.pump();
    expect(find.byType(app.ExpenseDashboardPage), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });
}
