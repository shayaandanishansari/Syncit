// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syncit/main.dart';
import 'package:syncit/services/settings_service.dart';
import 'package:syncit/services/sync_service.dart';

void main() {
  testWidgets('App should render without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SyncServiceNotifier()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const SyncItApp(),
      ),
    );

    expect(find.text('Welcome Shayaan'), findsOneWidget);
  });

  testWidgets('Settings page should show all settings options', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SyncServiceNotifier()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Ribbon Color'), findsOneWidget);
    expect(find.text('Background Color'), findsOneWidget);
    expect(find.text('Text Color'), findsOneWidget);
    expect(find.text('Sync Settings'), findsOneWidget);
    expect(find.text('Enable Sync'), findsOneWidget);
  });

  testWidgets('Folders page should show empty state initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SyncServiceNotifier()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const MaterialApp(
          home: FoldersPage(),
        ),
      ),
    );

    expect(find.text('No shared folders yet. Use the + button to add one.'), findsOneWidget);
  });

  testWidgets('Devices page should show empty state initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SyncServiceNotifier()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const MaterialApp(
          home: DevicesPage(),
        ),
      ),
    );

    expect(find.text('No devices connected yet'), findsOneWidget);
    expect(find.text('No devices found. Click refresh to search.'), findsOneWidget);
  });
}
