import 'package:flutter/material.dart';

import '../main.dart';
import '../services/notification_service.dart';
import '../widgets/ui_helpers.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final service = NotificationService();
  final threshold = TextEditingController();
  bool loading = true;
  bool enabled = false;
  bool recurring = true;
  bool budget = true;
  bool goal = true;
  bool forecast = true;
  bool advances = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _load();
  }

  Future<void> _load() async {
    final state = AppScope.of(context);
    final values = await Future.wait<String?>([
      state.database.getSetting('notifications_enabled'),
      state.database.getSetting('notifications_recurring'),
      state.database.getSetting('notifications_budget'),
      state.database.getSetting('notifications_goal'),
      state.database.getSetting('notifications_forecast'),
      state.database.getSetting('notifications_advances'),
      state.database.getSetting('notifications_low_balance_threshold'),
    ]);
    if (!mounted) return;
    setState(() {
      enabled = values[0] == '1';
      recurring = values[1] != '0';
      budget = values[2] != '0';
      goal = values[3] != '0';
      forecast = values[4] != '0';
      advances = values[5] != '0';
      threshold.text = values[6] ?? '0';
      loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final state = AppScope.of(context);
    await state.database.setSetting(key, value ? '1' : '0');
    await service.sync(state);
  }

  Future<void> _enable(bool value) async {
    if (value) {
      final granted = await service.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permesso notifiche non concesso.')),
          );
        }
        return;
      }
    }
    await _set('notifications_enabled', value);
    if (mounted) setState(() => enabled = value);
  }

  @override
  void dispose() {
    threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifiche locali')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notifiche'),
                subtitle: const Text(
                  'Tutte locali e opt-in. Nessun dato lascia il dispositivo.',
                ),
                value: enabled,
                onChanged: _enable,
              ),
              const SizedBox(height: 28),
              const SectionTitle('Avvisi'),
              _toggle(
                'Scadenze ricorrenti',
                'Un promemoria il giorno prima.',
                Icons.event_repeat_rounded,
                recurring,
                'notifications_recurring',
                (value) => recurring = value,
              ),
              _toggle(
                'Soglie budget',
                'Avvisa all’80% e al raggiungimento del limite.',
                Icons.pie_chart_outline_rounded,
                budget,
                'notifications_budget',
                (value) => budget = value,
              ),
              _toggle(
                'Obiettivi fuori ritmo',
                'Solo quando la situazione cambia materialmente.',
                Icons.flag_outlined,
                goal,
                'notifications_goal',
                (value) => goal = value,
              ),
              _toggle(
                'Anticipi',
                'Ricorda i soldi ancora da ricevere o restituire.',
                Icons.handshake_outlined,
                advances,
                'notifications_advances',
                (value) => advances = value,
              ),
              _toggle(
                'Saldo previsto basso',
                'Usa la previsione di fine mese e la tua soglia.',
                Icons.trending_down_rounded,
                forecast,
                'notifications_forecast',
                (value) => forecast = value,
              ),
              if (forecast) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: threshold,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Soglia saldo previsto',
                    suffixText: '€',
                    helperText: '0 disattiva la soglia.',
                  ),
                  onSubmitted: (_) => _saveThreshold(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: enabled ? _saveThreshold : null,
                    child: const Text('Salva soglia'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'DadaFinanza usa scheduling locale e limita i duplicati. Le ricorrenze automatiche vengono comunque riconciliate all’apertura dell’app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
  );

  Widget _toggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    String key,
    ValueChanged<bool> assign,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    secondary: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: enabled
        ? (next) async {
            await _set(key, next);
            if (mounted) setState(() => assign(next));
          }
        : null,
  );

  Future<void> _saveThreshold() async {
    final state = AppScope.of(context);
    final value = double.tryParse(threshold.text.replaceAll(',', '.')) ?? 0;
    await state.database.setSetting(
      'notifications_low_balance_threshold',
      value < 0 ? '0' : value.toStringAsFixed(2),
    );
    await service.sync(state);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Soglia salvata.')));
    }
  }
}
