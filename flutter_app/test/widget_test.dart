import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('app starts on the main menu', (WidgetTester tester) async {
    await tester.pumpWidget(const DragonHackApp());

    expect(find.text('DEPLOY'), findsOneWidget);
    expect(find.byIcon(Icons.settings_suggest_rounded), findsOneWidget);
  });

  testWidgets('settings loads and saves username and server url', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'username': 'Alice',
      'server_url': 'ws://192.168.0.10:8765',
    });

    await tester.pumpWidget(const DragonHackApp());
    await tester.tap(find.byIcon(Icons.settings_suggest_rounded));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(0), 'Bob');
    await tester.enterText(find.byType(TextField).at(1), '192.168.0.11:8765');
    await tester.tap(find.text('SAVE SETTINGS'));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('username'), 'Bob');
    expect(prefs.getString('server_url'), 'ws://192.168.0.11:8765');
  });
}
