import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();
  static final AppPreferences instance = AppPreferences._();

  static const _pinEnabledKey = 'pin_enabled';
  static const _pinHashKey = 'pin_hash';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _darkModeKey = 'dark_mode';
  static const _pinSetupCompleteKey = 'pin_setup_complete';

  SharedPreferences? _prefs;
  final Map<String, Object> _memory = <String, Object>{};
  bool _useMemoryStore = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      _useMemoryStore = false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AppPreferences: using in-memory store ($error)');
      }
      _useMemoryStore = true;
      _prefs = null;
    }

    _initialized = true;
    await _migrateThemePreference();
  }

  Future<void> _migrateThemePreference() async {
    final stored = _getString(_darkModeKey);
    if (stored == null || stored == 'system') {
      await _setString(_darkModeKey, 'light');
    }
  }

  bool _getBool(String key, {bool defaultValue = false}) {
    if (_useMemoryStore || _prefs == null) {
      return (_memory[key] as bool?) ?? defaultValue;
    }
    return _prefs!.getBool(key) ?? defaultValue;
  }

  String? _getString(String key) {
    if (_useMemoryStore || _prefs == null) {
      return _memory[key] as String?;
    }
    return _prefs!.getString(key);
  }

  Future<void> _setBool(String key, bool value) async {
    if (_useMemoryStore || _prefs == null) {
      _memory[key] = value;
      return;
    }
    await _prefs!.setBool(key, value);
  }

  Future<void> _setString(String key, String value) async {
    if (_useMemoryStore || _prefs == null) {
      _memory[key] = value;
      return;
    }
    await _prefs!.setString(key, value);
  }

  Future<void> _remove(String key) async {
    if (_useMemoryStore || _prefs == null) {
      _memory.remove(key);
      return;
    }
    await _prefs!.remove(key);
  }

  Future<bool> get pinEnabled async {
    await init();
    return _getBool(_pinEnabledKey);
  }

  Future<bool> get biometricEnabled async {
    await init();
    return _getBool(_biometricEnabledKey);
  }

  Future<bool> get pinSetupComplete async {
    await init();
    return _getBool(_pinSetupCompleteKey);
  }

  Future<ThemeMode> get themeMode async {
    await init();
    final value = _getString(_darkModeKey) ?? 'light';
    if (value == 'dark') {
      return ThemeMode.dark;
    }
    // Default to light (pastel UI). Treat legacy "system" as light.
    return ThemeMode.light;
  }

  Future<void> setPinEnabled(bool enabled) async {
    await init();
    await _setBool(_pinEnabledKey, enabled);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await init();
    await _setBool(_biometricEnabledKey, enabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await init();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _setString(_darkModeKey, value);
  }

  Future<void> savePinHash(String hash) async {
    await init();
    await _setString(_pinHashKey, hash);
    await _setBool(_pinSetupCompleteKey, true);
  }

  Future<String?> get pinHash async {
    await init();
    return _getString(_pinHashKey);
  }

  Future<void> clearPin() async {
    await init();
    await _remove(_pinHashKey);
    await _setBool(_pinEnabledKey, false);
    await _setBool(_pinSetupCompleteKey, false);
    await _setBool(_biometricEnabledKey, false);
  }
}
