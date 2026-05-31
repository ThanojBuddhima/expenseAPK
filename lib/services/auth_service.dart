import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'app_preferences.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Biometrics require native platform plugins (Android/iOS/macOS).
  bool get biometricsSupported => !kIsWeb;

  String hashPin(String pin) =>
      pin.codeUnits.fold<int>(0, (a, b) => a + b * 31).toString();

  Future<bool> verifyPin(String pin) async {
    final stored = await AppPreferences.instance.pinHash;
    if (stored == null) {
      return false;
    }
    return stored == hashPin(pin);
  }

  Future<void> setPin(String pin) async {
    await AppPreferences.instance.savePinHash(hashPin(pin));
    await AppPreferences.instance.setPinEnabled(true);
  }

  Future<bool> canUseBiometrics() async {
    if (!biometricsSupported) {
      return false;
    }
    try {
      if (!await _localAuth.isDeviceSupported()) {
        return false;
      }
      if (!await _localAuth.canCheckBiometrics) {
        return false;
      }
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    if (!biometricsSupported) {
      return <BiometricType>[];
    }
    try {
      return await _localAuth.getAvailableBiometrics();
    } on Object {
      return <BiometricType>[];
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!biometricsSupported) {
      return false;
    }
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Smart Offline Expense Manager',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on Object {
      return false;
    }
  }

  Future<bool> requiresUnlock() async {
    return await AppPreferences.instance.pinEnabled;
  }
}
