import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Default colors
  Color _ribbonColor = Colors.lightBlue;
  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black;
  bool _syncEnabled = true;

  // Getters
  Color get ribbonColor => _ribbonColor;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;
  bool get syncEnabled => _syncEnabled;

  // Initialize settings from storage
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _ribbonColor = Color(prefs.getInt('ribbon_color') ?? Colors.lightBlue.value);
    _backgroundColor = Color(prefs.getInt('background_color') ?? Colors.white.value);
    _textColor = Color(prefs.getInt('text_color') ?? Colors.black.value);
    _syncEnabled = prefs.getBool('sync_enabled') ?? true;
    notifyListeners();
  }

  // Save settings to storage
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ribbon_color', _ribbonColor.value);
    await prefs.setInt('background_color', _backgroundColor.value);
    await prefs.setInt('text_color', _textColor.value);
    await prefs.setBool('sync_enabled', _syncEnabled);
    notifyListeners();
  }

  // Update settings
  void updateRibbonColor(Color color) {
    _ribbonColor = color;
    saveSettings();
  }

  void updateBackgroundColor(Color color) {
    _backgroundColor = color;
    saveSettings();
  }

  void updateTextColor(Color color) {
    _textColor = color;
    saveSettings();
  }

  void toggleSync(bool value) {
    _syncEnabled = value;
    saveSettings();
  }
} 