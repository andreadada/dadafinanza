import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

class AndroidWidgetsScreen extends StatefulWidget {
  const AndroidWidgetsScreen({super.key});

  @override
  State<AndroidWidgetsScreen> createState() => _AndroidWidgetsScreenState();
}

class _AndroidWidgetsScreenState extends State<AndroidWidgetsScreen> {
  bool checking = true;
  bool supported = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() => checking = false);
      return;
    }
    final value = await HomeWidget.isRequestPinWidgetSupported();
    if (mounted) {
      setState(() {
        supported = value ?? false;
        checking = false;
      });
    }
  }

  Future<void> _pin(String provider) async {
    try {
      await HomeWidget.requestPinWidget(
        androidName: provider,
        qualifiedAndroidName: 'com.dadafinanza.app.$provider',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apri il selettore widget del launcher e cerca DadaFinanza.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Widget Android')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'DadaFinanza sulla Home',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Scegli solo le informazioni che vuoi avere a colpo d’occhio. I dettagli restano nell’app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 26),
            _WidgetChoice(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Saldo',
              subtitle: 'Compatto · circa 2×1\nSaldo totale e accesso rapido all’app.',
              buttonLabel: 'Aggiungi Saldo',
              enabled: !checking && supported,
              onPressed: () => _pin('DadaBalanceWidgetProvider'),
            ),
            const Divider(height: 32),
            _WidgetChoice(
              icon: Icons.add_circle_outline_rounded,
              title: 'Quick Add',
              subtitle: 'Azioni · circa 2×2\nApri direttamente Spesa, Entrata o Trasferimento.',
              buttonLabel: 'Aggiungi Quick Add',
              enabled: !checking && supported,
              onPressed: () => _pin('DadaQuickAddWidgetProvider'),
            ),
            const Divider(height: 32),
            _WidgetChoice(
              icon: Icons.space_dashboard_outlined,
              title: 'Riepilogo',
              subtitle: 'Completo · circa 4×2\nSaldo e quattro categorie rapide configurate dai tuoi dati.',
              buttonLabel: 'Aggiungi Riepilogo',
              enabled: !checking && supported,
              onPressed: () => _pin('DadaFinanceWidgetProvider'),
            ),
            const SizedBox(height: 28),
            if (checking)
              const Center(child: CircularProgressIndicator())
            else if (!supported)
              Text(
                Platform.isAndroid
                    ? 'Il launcher non supporta l’aggiunta automatica. Tieni premuto sulla schermata Home → Widget → DadaFinanza.'
                    : 'I widget di questa sezione sono disponibili su Android.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Text(
                'Android può chiederti una conferma prima di posizionare il widget.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      );
}

class _WidgetChoice extends StatelessWidget {
  const _WidgetChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$title. $subtitle',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.add_to_home_screen_rounded),
              label: Text(buttonLabel),
            ),
          ],
        ),
      );
}
