import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/haptic_service.dart';
import '../widgets/ui_helpers.dart';
import 'android_widgets_screen.dart';
import 'advances_screen.dart';
import 'category_management_screen.dart';
import 'data_management_screen.dart';
import 'local_privacy_screen.dart';
import 'notification_settings_screen.dart';
import 'preset_management_screen.dart';
import 'rules_management_screen.dart';
import 'settings_screen.dart'
    show DashboardCustomizerScreen, SmartSuggestionsSettingsScreen;
import 'voice_settings_screen.dart';

class PersonalSettingsScreen extends StatelessWidget {
  const PersonalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          const SectionTitle('Aspetto'),
          _Link(
            icon: Icons.contrast_rounded,
            title: 'Tema',
            subtitle: switch (state.themePreference) {
              AppThemePreference.system => 'Sistema',
              AppThemePreference.light => 'Chiaro',
              AppThemePreference.dark => 'Scuro',
            },
            onTap: () => _pickTheme(context, state),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Nascondi saldi nell’app'),
            subtitle: const Text(
              'Nasconde gli importi finanziari nelle viste principali.',
            ),
            value: state.hideBalance,
            onChanged: (value) => _setHideBalance(state, value),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Privacy locale'),
          _Link(
            icon: Icons.fingerprint_rounded,
            title: 'Blocco e schermata recenti',
            subtitle: 'Biometria o PIN · timeout · protezione screenshot',
            onTap: () => _open(context, const LocalPrivacyScreen()),
          ),
          _Link(
            icon: Icons.notifications_none_rounded,
            title: 'Notifiche locali',
            subtitle: 'Scadenze, anticipi, budget, obiettivi e cash-flow',
            onTap: () => _open(context, const NotificationSettingsScreen()),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Inserimento'),
          _Link(
            icon: Icons.mic_none_rounded,
            title: 'Inserimento vocale',
            subtitle: 'Parser locale · on-device quando disponibile',
            onTap: () => _open(context, const VoiceSettingsScreen()),
          ),
          _Link(
            icon: Icons.bolt_outlined,
            title: 'Smart Suggestions',
            subtitle: state.smartSuggestionsEnabled
                ? '${state.learnedPatterns.length} pattern appresi'
                : 'Disattivate',
            onTap: () => _open(context, const SmartSuggestionsSettingsScreen()),
          ),
          _Link(
            icon: Icons.bookmark_add_outlined,
            title: 'Preset rapidi',
            subtitle: 'Caffè, benzina, spesa e azioni personalizzate',
            onTap: () => _open(context, const PresetManagementScreen()),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Organizzazione'),
          _Link(
            icon: Icons.handshake_outlined,
            title: 'Anticipi',
            subtitle:
                '${state.advances.where((item) => item.closedKind == null && state.advanceRemainingCents(item.id) > 0).length} aperti · persone e storico',
            onTap: () => _open(context, const AdvancesScreen()),
          ),
          _Link(
            icon: Icons.category_outlined,
            title: 'Categorie',
            subtitle:
                '${state.categories.length} categorie · preferite e quick slot',
            onTap: () => _open(context, const CategoryManagementScreen()),
          ),
          _Link(
            icon: Icons.auto_fix_high_outlined,
            title: 'Regole automatiche',
            subtitle: '${state.rules.length} regole · priorità e test',
            onTap: () => _open(context, const RulesManagementScreen()),
          ),
          _Link(
            icon: Icons.dashboard_customize_outlined,
            title: 'Personalizza Home',
            subtitle: 'Mostra, nascondi, ridimensiona e riordina i widget',
            onTap: () => _open(context, const DashboardCustomizerScreen()),
          ),
          _Link(
            icon: Icons.widgets_outlined,
            title: 'Widget Android',
            subtitle:
                'Saldo, Quick Capture, importi rapidi e riepilogo configurabili',
            onTap: () => _open(context, const AndroidWidgetsScreen()),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Dati'),
          _Link(
            icon: Icons.folder_zip_outlined,
            title: 'Backup, CSV e ripristino',
            subtitle: 'Backup completo con allegati · import portabile',
            onTap: () => _open(context, const DataManagementScreen()),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Comportamento'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.help_outline_rounded),
            title: const Text('Permetti “Non assegnato”'),
            subtitle: const Text(
              'Registra velocemente e assegna il conto in seguito.',
            ),
            value: state.allowUnassigned,
            onChanged: (value) => _setBoolSetting(
              state,
              'allow_unassigned',
              value,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Trasferimenti nelle statistiche'),
            value: state.showTransfersInAnalytics,
            onChanged: (value) => _setBoolSetting(
              state,
              'show_transfers_analytics',
              value,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Feedback aptico'),
            subtitle: const Text(
              'Vibrazione leggera su navigazione, azioni rapide e impostazioni.',
            ),
            value: state.haptics,
            onChanged: (value) => _setHaptics(state, value),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    final state = AppScope.of(context);
    unawaited(HapticService.light(enabled: state.haptics));
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _setHideBalance(AppState state, bool value) async {
    await HapticService.light(enabled: state.haptics);
    await state.setHideBalance(value);
  }

  Future<void> _setBoolSetting(
    AppState state,
    String key,
    bool value,
  ) async {
    await HapticService.light(enabled: state.haptics);
    await state.setSetting(key, value ? '1' : '0');
  }

  Future<void> _setHaptics(AppState state, bool value) async {
    // Give one final confirmation when disabling, and immediate proof when
    // enabling, before persisting the new preference.
    await HapticService.medium(enabled: state.haptics || value);
    await state.setSetting('haptics', value ? '1' : '0');
  }

  Future<void> _pickTheme(BuildContext context, AppState state) async {
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tema', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...AppThemePreference.values.map(
              (value) => ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 10,
                leading: Icon(
                  value == state.themePreference
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                ),
                title: Text(switch (value) {
                  AppThemePreference.system => 'Sistema',
                  AppThemePreference.light => 'Chiaro',
                  AppThemePreference.dark => 'Scuro',
                }),
                onTap: () => Navigator.pop(sheetContext, value),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await HapticService.light(enabled: state.haptics);
      await state.setThemePreference(selected);
    }
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
