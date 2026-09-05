import 'dart:io';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputStatus {
  const VoiceInputStatus({
    required this.available,
    required this.onDevice,
    this.message,
  });

  final bool available;
  final bool onDevice;
  final String? message;
}

class VoiceInputService {
  VoiceInputService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  static const _channel = MethodChannel('dadafinanza/speech');
  final SpeechToText _speech;
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> isOnDeviceAvailable() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isOnDeviceAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isSystemRecognizerAvailable() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isRecognitionAvailable') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<VoiceInputStatus> prepare({
    required bool allowSystemRecognizer,
  }) async {
    final onDevice = await isOnDeviceAvailable();
    if (!onDevice && !allowSystemRecognizer) {
      return const VoiceInputStatus(
        available: false,
        onDevice: false,
        message:
            'Il riconoscimento vocale offline non è disponibile su questo dispositivo.',
      );
    }
    if (!onDevice && !await isSystemRecognizerAvailable()) {
      return const VoiceInputStatus(
        available: false,
        onDevice: false,
        message: 'Nessun servizio di riconoscimento vocale disponibile.',
      );
    }
    return VoiceInputStatus(available: true, onDevice: onDevice);
  }

  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError error) => onError(error.errorMsg),
    );
    return _initialized;
  }

  Future<void> listen({
    required bool onDevice,
    required void Function(String text, bool finalResult) onResult,
    void Function(double level)? onSoundLevel,
    String localeId = 'it_IT',
  }) async {
    if (!_initialized) throw StateError('VoiceInputService non inizializzato.');
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) =>
          onResult(result.recognizedWords, result.finalResult),
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        onDevice: onDevice,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        // The sheet decides after one second that the current phrase is stable,
        // while the platform recognizer stays alive so the user can keep talking
        // without seeing a brand-new prompt.
        pauseFor: const Duration(seconds: 30),
        listenFor: const Duration(seconds: 90),
        localeId: localeId,
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
