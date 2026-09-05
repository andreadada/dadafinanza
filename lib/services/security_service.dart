import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum AppLockMode { off, biometric, pin }

enum AppLockTimeout {
  immediate(0, 'Immediato'),
  oneMinute(60, '1 minuto'),
  fiveMinutes(300, '5 minuti'),
  fifteenMinutes(900, '15 minuti');

  const AppLockTimeout(this.seconds, this.label);
  final int seconds;
  final String label;
}

class SecurityService {
  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? auth,
  })  : storage = storage ?? const FlutterSecureStorage(),
        auth = auth ?? LocalAuthentication();

  static const _privacyChannel = MethodChannel('dadafinanza/privacy');
  static const _modeKey = 'security.lock_mode';
  static const _pinKey = 'security.pin';
  static const _timeoutKey = 'security.timeout';
  static const _secureRecentKey = 'security.secure_recent';

  final FlutterSecureStorage storage;
  final LocalAuthentication auth;

  DateTime? _backgroundedAt;

  Future<AppLockMode> mode() async {
    final raw = await storage.read(key: _modeKey);
    return AppLockMode.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AppLockMode.off,
    );
  }

  Future<void> setMode(AppLockMode value) =>
      storage.write(key: _modeKey, value: value.name);

  Future<AppLockTimeout> timeout() async {
    final raw = await storage.read(key: _timeoutKey);
    return AppLockTimeout.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AppLockTimeout.immediate,
    );
  }

  Future<void> setTimeout(AppLockTimeout value) =>
      storage.write(key: _timeoutKey, value: value.name);

  Future<bool> secureRecentApps() async =>
      (await storage.read(key: _secureRecentKey)) == '1';

  Future<void> setSecureRecentApps(bool enabled) async {
    await storage.write(key: _secureRecentKey, value: enabled ? '1' : '0');
    await applySecureRecentApps(enabled);
  }

  Future<void> applyStoredPrivacy() async =>
      applySecureRecentApps(await secureRecentApps());

  Future<void> applySecureRecentApps(bool enabled) async {
    try {
      await _privacyChannel.invokeMethod<void>(
        'setSecure',
        <String, Object?>{'enabled': enabled},
      );
    } on MissingPluginException {
      // Non-Android platforms simply ignore this Android-specific protection.
    }
  }

  Future<bool> biometricAvailable() async {
    try {
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await auth.authenticate(
        localizedReason: 'Sblocca DadaFinanza per vedere i tuoi dati finanziari',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final normalized = pin.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(normalized)) {
      throw ArgumentError('Il PIN deve contenere da 4 a 8 cifre.');
    }
    await storage.write(key: _pinKey, value: normalized);
  }

  Future<bool> hasPin() async => (await storage.read(key: _pinKey)) != null;

  Future<bool> verifyPin(String pin) async =>
      (await storage.read(key: _pinKey)) == pin.trim();

  Future<void> removePin() => storage.delete(key: _pinKey);

  void markBackgrounded([DateTime? now]) {
    _backgroundedAt = now ?? DateTime.now();
  }

  Future<bool> shouldLockOnResume([DateTime? now]) async {
    if (await mode() == AppLockMode.off) return false;
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt == null) return true;
    final limit = await timeout();
    return (now ?? DateTime.now()).difference(backgroundedAt).inSeconds >=
        limit.seconds;
  }
}
