import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_storage.dart';

class AppThemeMode extends ChangeNotifier {
  AppThemeMode() {
    _load();
  }
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  Future<void> _load() async {
    _themeMode = await ThemeStorage.readThemeMode();
    notifyListeners();
  }
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await ThemeStorage.writeThemeMode(mode);
  }
}

final appThemeModeProvider = ChangeNotifierProvider<AppThemeMode>((
  Ref ref,
) {
  return AppThemeMode();
});
