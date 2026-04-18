import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('app starts on main menu and shows buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DragonHackApp());

    expect(find.text('Main Menu'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Play'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Settings'), findsOneWidget);
  });

  testWidgets('play navigates to lobby with pending status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DragonHackApp());

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.text('Lobby'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('settings loads saved username', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'username': 'Alice'});

    await tester.pumpWidget(const DragonHackApp());

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('invalid username shows validation error and does not persist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DragonHackApp());

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.tap(find.text('Save Username'));
    await tester.pumpAndSettle();

    expect(find.text('Username must have at least 3 characters.'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('username'), isNull);
  });

  testWidgets('valid username persists and is shown when returning to settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DragonHackApp());

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  Bob  ');
    await tester.tap(find.text('Save Username'));
    await tester.pumpAndSettle();

    expect(find.text('Username saved.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('username'), 'Bob');
  });
}
