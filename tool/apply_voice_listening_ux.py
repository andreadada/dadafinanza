from pathlib import Path

quick_add = Path('lib/screens/quick_add_page.dart')
voice_service = Path('lib/services/voice_input_service.dart')
style_doc = Path('docs/LINEE_GUIDA_STYLE.md')

service_content = '''import 'dart:io';

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
  VoiceInputService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

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
'''
voice_service.write_text(service_content, encoding='utf-8')

source = quick_add.read_text(encoding='utf-8')
source = source.replace(
    "      showDragHandle: true,\n      builder: (_) =>\n          _VoiceListeningSheet(voice: voice, onDevice: status.onDevice),",
    "      builder: (_) =>\n          _VoiceListeningSheet(voice: voice, onDevice: status.onDevice),",
    1,
)
source = source.replace(
    "                  ButtonSegment(\n                    value: TransactionType.transfer,\n                    label: Text('Trasferimento'),\n                  ),",
    "                  ButtonSegment(\n                    value: TransactionType.transfer,\n                    label: Text('Trasferisci', maxLines: 1),\n                  ),",
    1,
)

start = source.index('class _VoiceListeningSheet extends StatefulWidget')
end = source.index('class _PickerRow extends StatelessWidget')
new_sheet = r'''class _VoiceListeningSheet extends StatefulWidget {
  const _VoiceListeningSheet({required this.voice, required this.onDevice});

  final VoiceInputService voice;
  final bool onDevice;

  @override
  State<_VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<_VoiceListeningSheet> {
  static const _silenceWindow = Duration(seconds: 1);
  static const _waveBarCount = 20;

  String partial = '';
  String? error;
  bool ready = false;
  bool settled = false;
  bool closing = false;
  bool restarting = false;
  Timer? _silenceTimer;
  DateTime _lastWaveUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  final List<double> _levels = List<double>.filled(_waveBarCount, 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    unawaited(widget.voice.cancel());
    super.dispose();
  }

  Future<void> _begin({bool clearTranscript = false}) async {
    _silenceTimer?.cancel();
    if (clearTranscript && mounted) {
      setState(() {
        partial = '';
        error = null;
        ready = false;
        settled = false;
        for (var index = 0; index < _levels.length; index++) {
          _levels[index] = 0;
        }
      });
    }

    final initialized = await widget.voice.initialize(
      onStatus: (status) {
        if (!mounted || closing) return;
        final normalized = status.toLowerCase();
        if (normalized == 'listening') {
          setState(() => ready = true);
        } else if (normalized == 'done' || normalized == 'notlistening') {
          setState(() {
            ready = false;
            if (partial.trim().isNotEmpty) settled = true;
          });
        }
      },
      onError: (message) {
        if (!mounted || closing) return;
        final friendly = _friendlyError(message);
        final value = message.toLowerCase();
        final harmlessAfterSpeech =
            partial.trim().isNotEmpty &&
            (value.contains('no_match') || value.contains('speech_timeout'));
        setState(() {
          ready = false;
          if (harmlessAfterSpeech) {
            settled = true;
          } else {
            error = friendly;
          }
        });
      },
    );
    if (!initialized) {
      if (mounted) {
        setState(
          () => error =
              'Permesso microfono negato o riconoscimento non disponibile.',
        );
      }
      return;
    }

    try {
      await widget.voice.listen(
        onDevice: widget.onDevice,
        onSoundLevel: _onSoundLevel,
        onResult: (text, finalResult) {
          if (!mounted || closing) return;
          final cleaned = text.trim();
          if (cleaned.isEmpty) return;
          final changed = cleaned != partial.trim();
          setState(() {
            partial = text;
            ready = !finalResult;
            settled = finalResult;
            error = null;
          });
          if (finalResult) {
            _silenceTimer?.cancel();
          } else if (changed) {
            _markActivePhrase();
          }
        },
      );
    } catch (exception) {
      if (mounted && !closing) {
        setState(() => error = _friendlyError('$exception'));
      }
    }
  }

  void _markActivePhrase() {
    _silenceTimer?.cancel();
    if (mounted && settled) setState(() => settled = false);
    _silenceTimer = Timer(_silenceWindow, () {
      if (!mounted || closing || partial.trim().isEmpty) return;
      setState(() => settled = true);
    });
  }

  void _onSoundLevel(double level) {
    if (!mounted || closing) return;
    final now = DateTime.now();
    if (now.difference(_lastWaveUpdate) < const Duration(milliseconds: 55)) {
      return;
    }
    _lastWaveUpdate = now;
    setState(() {
      _levels.removeAt(0);
      _levels.add(level);
    });
  }

  Future<void> _restart() async {
    if (restarting || closing) return;
    setState(() => restarting = true);
    await widget.voice.cancel();
    if (!mounted || closing) return;
    await _begin(clearTranscript: true);
    if (mounted && !closing) setState(() => restarting = false);
  }

  Future<void> _close() async {
    if (closing) return;
    closing = true;
    _silenceTimer?.cancel();
    await widget.voice.cancel();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _accept() async {
    final result = partial.trim();
    if (result.isEmpty || closing) return;
    closing = true;
    _silenceTimer?.cancel();
    await widget.voice.stop();
    if (mounted) Navigator.pop(context, result);
  }

  String _friendlyError(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('permission')) {
      return 'Il permesso microfono non è disponibile.';
    }
    if (value.contains('no_match')) {
      return 'Non ho riconosciuto parole. Puoi ricominciare.';
    }
    if (value.contains('network')) {
      return 'Il recognizer di sistema non è disponibile offline.';
    }
    return 'Riconoscimento vocale non riuscito. Puoi ricominciare.';
  }

  @override
  Widget build(BuildContext context) {
    final hasTranscript = partial.trim().isNotEmpty;
    final title = error != null
        ? 'Riconoscimento interrotto'
        : settled && hasTranscript
        ? 'Ho capito'
        : ready
        ? 'Ti ascolto'
        : 'Preparo il microfono…';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Ricomincia',
                onPressed: restarting ? null : _restart,
                icon: restarting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt_rounded),
              ),
              IconButton(
                tooltip: 'Chiudi',
                onPressed: _close,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _VoiceWaveform(levels: _levels, active: ready && error == null),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            label: error ?? (hasTranscript ? partial : 'In ascolto'),
            child: Text(
              error ?? (hasTranscript ? '“$partial”' : 'Parla normalmente…'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (settled && hasTranscript && error == null) ...[
            const SizedBox(height: 8),
            Text(
              'Rimane qui. Se continui a parlare, aggiorno la frase; usa ↻ per ricominciare da zero.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasTranscript && error == null ? _accept : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Usa questo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.levels, required this.active});

  final List<double> levels;
  final bool active;

  @override
  Widget build(BuildContext context) {
    var minimum = levels.first;
    var maximum = levels.first;
    for (final level in levels.skip(1)) {
      if (level < minimum) minimum = level;
      if (level > maximum) maximum = level;
    }
    final range = maximum - minimum;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: active ? 'Livello microfono attivo' : 'Livello microfono in pausa',
      child: SizedBox(
        height: 52,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < levels.length; index++) ...[
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 70),
                    curve: Curves.easeOut,
                    width: 3,
                    height:
                        8 +
                        36 *
                            (range.abs() < 0.05
                                ? 0.08
                                : ((levels[index] - minimum) / range)
                                      .clamp(0.08, 1.0)),
                    decoration: BoxDecoration(
                      color: active
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              if (index != levels.length - 1) const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

'''
source = source[:start] + new_sheet + source[end:]
quick_add.write_text(source, encoding='utf-8')

if style_doc.exists():
    style = style_doc.read_text(encoding='utf-8')
    style = style.replace(
        '- badge/testo `Sul dispositivo` quando effettivamente on-device;\n',
        '- waveform semplice derivata dal livello microfono quando disponibile;\n'
        '- niente badge tecnico ridondante nel modal: la privacy/on-device resta esplicitata nelle Impostazioni;\n',
    )
    style = style.replace(
        '- azioni `Annulla` e `Termina`;\n',
        '- `X` in alto a destra per chiudere, icona restart per ripartire da zero e conferma separata `Usa questo`;\n'
        '- dopo circa 1 secondo senza nuovi risultati la trascrizione resta visibile nel modal senza resettarsi; se il recognizer è ancora attivo, nuovo parlato aggiorna la stessa frase;\n',
    )
    style_doc.write_text(style, encoding='utf-8')

contract = Path('test/voice_listening_ux_contract_test.dart')
contract.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice modal keeps transcript and exposes restart, close and waveform', () async {
    final source = await File('lib/screens/quick_add_page.dart').readAsString();
    expect(source, contains('Icons.restart_alt_rounded'));
    expect(source, contains('Icons.close_rounded'));
    expect(source, contains('_VoiceWaveform'));
    expect(source, contains("const _silenceWindow = Duration(seconds: 1)"));
    expect(source, contains("label: const Text('Usa questo')"));
    expect(source, isNot(contains("Text('Annulla')")));
    expect(source, isNot(contains("label: Text('Sul dispositivo')")));
  });

  test('voice service keeps recognition session alive after short pauses', () async {
    final source = await File('lib/services/voice_input_service.dart').readAsString();
    expect(source, contains('onSoundLevelChange: onSoundLevel'));
    expect(source, contains('listenMode: ListenMode.dictation'));
    expect(source, contains('pauseFor: const Duration(seconds: 30)'));
  });

  test('transfer segment uses a single-line compact action label', () async {
    final source = await File('lib/screens/quick_add_page.dart').readAsString();
    expect(source, contains("label: Text('Trasferisci', maxLines: 1)"));
  });
}
''', encoding='utf-8')
