import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../widgets/ui_helpers.dart';

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
          content: Text(
            'Apri il selettore widget del launcher e cerca DadaFinanza.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Widget Android')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
      children: [
        Text(
          'DadaFinanza sulla Home',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Ogni istanza può avere impostazioni proprie. Il widget apre sempre Quick Add: nessun tap registra denaro senza la tua conferma.',
        ),
        const SizedBox(height: 28),
        const SectionTitle('Widget disponibili'),
        _WidgetChoice(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Saldo',
          subtitle: 'Circa 2×1 · saldo compatto e accesso a Nuovo movimento. La visibilità del saldo è configurabile per istanza.',
          buttonLabel: 'Aggiungi Saldo',
          enabled: !checking && supported,
          onPressed: () => _pin('DadaBalanceWidgetProvider'),
        ),
        const Divider(height: 32),
        _WidgetChoice(
          icon: Icons.mic_none_rounded,
          title: 'Quick Capture',
          subtitle: 'Circa 2×2 · Spesa, Entrata, Trasferisci e Voce. Conto e categoria possono essere preconfigurati.',
          buttonLabel: 'Aggiungi Quick Capture',
          enabled: !checking && supported,
          onPressed: () => _pin('DadaQuickAddWidgetProvider'),
        ),
        const Divider(height: 32),
        _WidgetChoice(
          icon: Icons.pin_outlined,
          title: 'Importi rapidi',
          subtitle: 'Circa 4×2 · quattro importi personalizzati, conto, categoria, trasferimento e microfono.',
          buttonLabel: 'Aggiungi Importi rapidi',
          enabled: !checking && supported,
          onPressed: () => _pin('DadaQuickAmountsWidgetProvider'),
        ),
        const Divider(height: 32),
        _WidgetChoice(
          icon: Icons.space_dashboard_outlined,
          title: 'Riepilogo',
          subtitle: 'Circa 4×2 · saldo e quattro categorie rapide. Le categorie seguono prima i quick slot e poi le preferite.',
          buttonLabel: 'Aggiungi Riepilogo',
          enabled: !checking && supported,
          onPressed: () => _pin('DadaFinanceWidgetProvider'),
        ),
        const SizedBox(height: 32),
        const SectionTitle('Privacy widget'),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.visibility_off_outlined),
          title: Text('Separata dall’app'),
          subtitle: Text(
            'Durante la configurazione puoi scegliere se mostrare saldo e importi. “Nascondi saldi” nell’app prevale comunque e oscura i widget.',
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.tune_rounded),
          title: Text('Configurazione per istanza'),
          subtitle: Text(
            'Puoi avere, per esempio, un widget Revolut/Bar e un altro Contanti/Benzina con importi diversi.',
          ),
        ),
        const SizedBox(height: 20),
        if (checking)
          const Center(child: CircularProgressIndicator())
        else if (!supported)
          Text(
            Platform.isAndroid
                ? 'Il launcher non supporta l’aggiunta automatica. Tieni premuto sulla Home → Widget → DadaFinanza.'
                : 'I widget di questa sezione sono disponibili su Android.',
          )
        else
          Text(
            'Android può chiederti conferma e aprire la configurazione prima di posizionare il widget.',
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
            Icon(icon, size: 28),
            const SizedBox(width: 12),
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
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: const Icon(Icons.add_to_home_screen_rounded),
          label: Text(buttonLabel),
        ),
      ],
    ),
  );
}
