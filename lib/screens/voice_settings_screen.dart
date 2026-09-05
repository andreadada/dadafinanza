import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/ui_helpers.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  bool loading = true;
  bool enabled = true;
  bool onDeviceOnly = true;
  bool allowSystem = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _load();
  }

  Future<void> _load() async {
    final state = AppScope.of(context);
    final values = await Future.wait([
      state.database.getSetting('voice_enabled'),
      state.database.getSetting('voice_on_device_only'),
      state.database.getSetting('voice_allow_system_recognizer'),
    ]);
    if (!mounted) return;
    final localOnly = (values[1] ?? '1') == '1';
    setState(() {
      enabled = (values[0] ?? '1') == '1';
      onDeviceOnly = localOnly;
      allowSystem = !localOnly && (values[2] ?? '0') == '1';
      loading = false;
    });
    if (localOnly && (values[2] ?? '0') == '1') {
      await state.setSetting('voice_allow_system_recognizer', '0');
    }
  }

  Future<void> _set(String key, bool value) async {
    final state = AppScope.of(context);
    await state.setSetting(key, value ? '1' : '0');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inserimento vocale')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              const SectionTitle('Voce'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Abilita inserimento vocale'),
                subtitle: const Text(
                  'Il microfono compila Nuovo movimento ma non salva mai automaticamente.',
                ),
                value: enabled,
                onChanged: (value) async {
                  setState(() => enabled = value);
                  await _set('voice_enabled', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Solo sul dispositivo'),
                subtitle: const Text(
                  'Usa esclusivamente il riconoscimento offline/on-device quando Android lo supporta.',
                ),
                value: onDeviceOnly,
                onChanged: !enabled
                    ? null
                    : (value) async {
                        setState(() {
                          onDeviceOnly = value;
                          if (value) allowSystem = false;
                        });
                        await _set('voice_on_device_only', value);
                        if (value) {
                          await _set('voice_allow_system_recognizer', false);
                        }
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Consenti recognizer di sistema'),
                subtitle: const Text(
                  'Fallback opzionale. La privacy dipende dal servizio vocale configurato sul dispositivo.',
                ),
                value: allowSystem,
                onChanged: !enabled || onDeviceOnly
                    ? null
                    : (value) async {
                        setState(() => allowSystem = value);
                        await _set('voice_allow_system_recognizer', value);
                      },
              ),
              const SizedBox(height: 24),
              const SectionTitle('Lingua'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.language_rounded),
                title: Text('Italiano (Italia)'),
                subtitle: Text(
                  'it_IT · comandi brevi per movimenti finanziari',
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle('Privacy'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.phonelink_lock_outlined),
                title: Text('Nessun assistente cloud DadaFinanza'),
                subtitle: Text(
                  'Il testo riconosciuto viene interpretato localmente da un parser deterministico. Non viene inviato a server DadaFinanza.',
                ),
              ),
            ],
          ),
  );
}
