import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kThemeModePreferenceKey = 'themeMode';

class ThemeStorage {
  ThemeStorage._();

  static Future<ThemeMode> readThemeMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(kThemeModePreferenceKey);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> writeThemeMode(ThemeMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(kThemeModePreferenceKey, value);
  }
}
