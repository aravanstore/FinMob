import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  bool get isLight => _mode == ThemeMode.light;

  ThemeController() {
    _load();
  }

  Future<void> toggle() async {
    _mode = isLight ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefKey);
      final loaded = switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.dark,
      };
      if (_mode != loaded) {
        _mode = loaded;
        notifyListeners();
      }
    } catch (_) {
      // ignore: if prefs unavailable, keep default
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = switch (_mode) { ThemeMode.light => 'light', _ => 'dark' };
      await prefs.setString(_prefKey, v);
    } catch (_) {
      // ignore
    }
  }
}

