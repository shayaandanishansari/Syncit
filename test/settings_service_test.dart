import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:syncit/services/settings_service.dart';

void main() {
  late SettingsService settingsService;

  setUp(() {
    settingsService = SettingsService();
  });

  group('SettingsService Tests', () {
    test('initial values should be set correctly', () {
      expect(settingsService.ribbonColor, Colors.blue);
      expect(settingsService.backgroundColor, Colors.white);
      expect(settingsService.textColor, Colors.black);
      expect(settingsService.syncEnabled, true);
    });

    test('updateRibbonColor should change ribbon color', () {
      settingsService.updateRibbonColor(Colors.red);
      expect(settingsService.ribbonColor, Colors.red);
    });

    test('updateBackgroundColor should change background color', () {
      settingsService.updateBackgroundColor(Colors.grey);
      expect(settingsService.backgroundColor, Colors.grey);
    });

    test('updateTextColor should change text color', () {
      settingsService.updateTextColor(Colors.green);
      expect(settingsService.textColor, Colors.green);
    });

    test('toggleSync should change sync enabled state', () {
      settingsService.toggleSync(false);
      expect(settingsService.syncEnabled, false);
      
      settingsService.toggleSync(true);
      expect(settingsService.syncEnabled, true);
    });
  });
} 