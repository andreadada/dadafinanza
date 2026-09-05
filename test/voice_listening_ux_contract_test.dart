import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'voice modal keeps transcript and exposes restart, close and waveform',
    () async {
      final source = await File(
        'lib/screens/quick_add_page.dart',
      ).readAsString();
      expect(source, contains('Icons.restart_alt_rounded'));
      expect(source, contains('Icons.close_rounded'));
      expect(source, contains('_VoiceWaveform'));
      expect(source, contains("const _silenceWindow = Duration(seconds: 1)"));
      expect(source, contains("label: const Text('Usa questo')"));
      expect(source, isNot(contains("Text('Annulla')")));
      expect(source, isNot(contains("label: Text('Sul dispositivo')")));
    },
  );

  test(
    'voice service keeps recognition session alive after short pauses',
    () async {
      final source = await File(
        'lib/services/voice_input_service.dart',
      ).readAsString();
      expect(source, contains('onSoundLevelChange: onSoundLevel'));
      expect(source, contains('listenMode: ListenMode.dictation'));
      expect(source, contains('pauseFor: const Duration(seconds: 30)'));
    },
  );

  test('transfer segment uses a single-line compact action label', () async {
    final source = await File('lib/screens/quick_add_page.dart').readAsString();
    expect(source, contains("'Trasferimento'"));
    expect(source, contains('fit: BoxFit.scaleDown'));
    expect(source, contains('softWrap: false'));
  });
}
