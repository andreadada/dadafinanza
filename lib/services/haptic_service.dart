import 'package:flutter/services.dart';

/// Centralized haptic feedback for DadaFinanza.
///
/// Keeping haptics behind one service makes the user preference effective
/// everywhere and prevents unsupported platform feedback from crashing the app.
abstract final class HapticService {
  static Future<void> selection({required bool enabled}) =>
      _run(enabled, HapticFeedback.selectionClick);

  static Future<void> light({required bool enabled}) =>
      _run(enabled, HapticFeedback.lightImpact);

  static Future<void> medium({required bool enabled}) =>
      _run(enabled, HapticFeedback.mediumImpact);

  static Future<void> heavy({required bool enabled}) =>
      _run(enabled, HapticFeedback.heavyImpact);

  static Future<void> _run(
    bool enabled,
    Future<void> Function() feedback,
  ) async {
    if (!enabled) return;
    try {
      await feedback();
    } on MissingPluginException {
      // Haptics are optional on unsupported/test platforms.
    } on PlatformException {
      // Do not let unavailable device feedback break the interaction.
    }
  }
}
