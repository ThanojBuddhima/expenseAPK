import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expence_apk/main.dart' as app;

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const app.MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(app.ExpenseDashboardPage), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
