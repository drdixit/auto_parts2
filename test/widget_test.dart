// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_parts2/screens/home_screen.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Pump only the DashboardTab inside a MaterialApp to avoid DB initialization
    await tester.pumpWidget(const MaterialApp(home: DashboardTab()));

    // Verify that the dashboard displays the welcome text.
    expect(find.text('Welcome to Auto Parts Inventory'), findsOneWidget);
  });
}
