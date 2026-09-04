import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

String moneyValue(double value, {String currency = 'EUR', bool showCents = true, bool signed = false}) {
  final formatter = NumberFormat.currency(locale: 'it_IT', name: currency, decimalDigits: showCents ? 2 : 0);
  final base = formatter.format(value.abs());
  if (!signed || value == 0) return base;
  return '${value > 0 ? '+' : '-'}$base';
}

String moneyFor(AppState state, double value, {bool signed = false}) => moneyValue(value, currency: state.currency, showCents: state.showCents, signed: signed);
String money(double value, {bool signed = false}) => moneyValue(value, signed: signed);

class IconOption {
  const IconOption(this.key, this.icon, this.label);
  final String key;
  final IconData icon;
  final String label;
}

const categoryIconOptions = <IconOption>[
  IconOption('category', Icons.category_rounded, 'Generica'),
  IconOption('home', Icons.home_rounded, 'Casa'),
  IconOption('cart', Icons.shopping_cart_rounded, 'Spesa'),
  IconOption('grocery', Icons.local_grocery_store_rounded, 'Supermercato'),
  IconOption('restaurant', Icons.restaurant_rounded, 'Ristorante'),
  IconOption('coffee', Icons.local_cafe_rounded, 'Bar e caffè'),
  IconOption('car', Icons.directions_car_rounded, 'Auto'),
  IconOption('fuel', Icons.local_gas_station_rounded, 'Benzina'),
  IconOption('bus', Icons.directions_bus_rounded, 'Trasporti'),
  IconOption('train', Icons.train_rounded, 'Treno'),
  IconOption('flight', Icons.flight_rounded, 'Volo'),
  IconOption('travel', Icons.luggage_rounded, 'Viaggio'),
  IconOption('health', Icons.favorite_rounded, 'Salute'),
  IconOption('pharmacy', Icons.local_pharmacy_rounded, 'Farmacia'),
  IconOption('sport', Icons.sports_soccer_rounded, 'Sport'),
  IconOption('fitness', Icons.fitness_center_rounded, 'Palestra'),
  IconOption('shopping', Icons.shopping_bag_rounded, 'Shopping'),
  IconOption('clothes', Icons.checkroom_rounded, 'Vestiti'),
  IconOption('tech', Icons.devices_rounded, 'Tecnologia'),
  IconOption('gaming', Icons.sports_esports_rounded, 'Videogiochi'),
  IconOption('movie', Icons.movie_rounded, 'Cinema'),
  IconOption('streaming', Icons.ondemand_video_rounded, 'Streaming'),
  IconOption('school', Icons.school_rounded, 'Scuola'),
  IconOption('university', Icons.account_balance_rounded, 'Università'),
  IconOption('work', Icons.work_rounded, 'Lavoro'),
  IconOption('gift', Icons.card_giftcard_rounded, 'Regalo'),
  IconOption('pets', Icons.pets_rounded, 'Animali'),
  IconOption('family', Icons.groups_rounded, 'Famiglia'),
  IconOption('child', Icons.child_care_rounded, 'Bambini'),
  IconOption('bills', Icons.receipt_long_rounded, 'Bollette'),
  IconOption('phone', Icons.phone_android_rounded, 'Telefono'),
  IconOption('internet', Icons.wifi_rounded, 'Internet'),
  IconOption('insurance', Icons.shield_rounded, 'Assicurazione'),
  IconOption('tax', Icons.request_quote_rounded, 'Tasse'),
  IconOption('salary', Icons.payments_rounded, 'Stipendio'),
  IconOption('freelance', Icons.laptop_mac_rounded, 'Freelance'),
  IconOption('investment', Icons.trending_up_rounded, 'Investimento'),
  IconOption('interest', Icons.percent_rounded, 'Interessi'),
  IconOption('refund', Icons.replay_rounded, 'Rimborso'),
  IconOption('sale', Icons.sell_rounded, 'Vendita'),
  IconOption('charity', Icons.volunteer_activism_rounded, 'Donazione'),
  IconOption('event', Icons.event_rounded, 'Evento'),
  IconOption('other', Icons.more_horiz_rounded, 'Altro'),
];

const accountIconOptions = <IconOption>[
  IconOption('wallet', Icons.account_balance_wallet_rounded, 'Portafoglio'),
  IconOption('bank', Icons.account_balance_rounded, 'Banca'),
  IconOption('card', Icons.credit_card_rounded, 'Carta'),
  IconOption('cash', Icons.payments_rounded, 'Contanti'),
  IconOption('savings', Icons.savings_rounded, 'Risparmio'),
  IconOption('safe', Icons.lock_rounded, 'Cassaforte'),
  IconOption('investment', Icons.show_chart_rounded, 'Investimenti'),
  IconOption('home', Icons.home_work_rounded, 'Casa'),
  IconOption('business', Icons.business_center_rounded, 'Business'),
  IconOption('crypto', Icons.currency_bitcoin_rounded, 'Asset digitale'),
  IconOption('travel', Icons.flight_takeoff_rounded, 'Viaggio'),
  IconOption('help', Icons.help_outline_rounded, 'Non assegnato'),
];

const categoryPalette = <Color>[
  Color(0xFF8E8E93), Color(0xFF59636F), Color(0xFF5B78D4), Color(0xFF6C8DCB),
  Color(0xFFAF6C5A), Color(0xFFC65A67), Color(0xFF8C6FB1), Color(0xFFB47A43),
  Color(0xFF4F7A71), Color(0xFF6E6E73),
];

IconData _iconFor(String key, List<IconOption> options, IconData fallback) {
  for (final option in options) { if (option.key == key) return option.icon; }
  return fallback;
}
IconData categoryIcon(String key) => _iconFor(key, categoryIconOptions, Icons.category_rounded);
IconData accountIcon(String key) => _iconFor(key, accountIconOptions, Icons.account_balance_wallet_rounded);

Color transactionColor(BuildContext context, TransactionType type) => switch (type) {
  TransactionType.expense => context.financeColors.negative,
  TransactionType.income => context.financeColors.positive,
  TransactionType.transfer => context.financeColors.neutral,
};

Future<bool> confirmDestructiveAction(BuildContext context, {required String title, required String message, String confirmLabel = 'Elimina'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ?? false;

Future<String?> showIconPicker(BuildContext context, {required List<IconOption> options, required String selected}) async {
  final search = TextEditingController();
  var query = '';
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(builder: (context, setState) {
      final filtered = options.where((o) => o.label.toLowerCase().contains(query.toLowerCase())).toList();
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scegli icona', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Cerca icona'), onChanged: (value) => setState(() => query = value)),
            const SizedBox(height: 14),
            Expanded(child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final option = filtered[index]; final active = option.key == selected;
                return Tooltip(message: option.label, child: Semantics(
                  button: true, selected: active, label: option.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, option.key),
                    child: Ink(
                      decoration: BoxDecoration(color: active ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                      child: Icon(option.icon),
                    ),
                  ),
                ));
              },
            )),
          ]),
        ),
      );
    }),
  );
  search.dispose();
  return result;
}

Future<Category?> showCategoryCreator(BuildContext context, AppState state, {TransactionType initialType = TransactionType.expense, bool lockType = false}) async {
  final controller = TextEditingController();
  var type = initialType;
  var iconKey = 'category';
  var color = categoryPalette.first;
  final result = await showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(builder: (context, setSheetState) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nuova categoria', style: Theme.of(context).textTheme.titleLarge),
        TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Es. Benzina')),
        if (!lockType) ...[
          const SizedBox(height: 16),
          SegmentedButton<TransactionType>(showSelectedIcon: false, segments: const [ButtonSegment(value: TransactionType.expense, label: Text('Spesa')), ButtonSegment(value: TransactionType.income, label: Text('Entrata'))], selected: {type}, onSelectionChanged: (value) => setSheetState(() => type = value.first)),
        ],
        const SizedBox(height: 18),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(categoryIcon(iconKey)), title: const Text('Icona'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () async {
          final selected = await showIconPicker(context, options: categoryIconOptions, selected: iconKey);
          if (selected != null) setSheetState(() => iconKey = selected);
        }),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: categoryPalette.map((item) => Semantics(
          button: true, selected: item == color, label: 'Colore categoria',
          child: InkWell(customBorder: const CircleBorder(), onTap: () => setSheetState(() => color = item), child: SizedBox.square(dimension: 48, child: Center(child: Container(width: 30, height: 30, decoration: BoxDecoration(color: item, shape: BoxShape.circle), child: item == color ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null))))
        )).toList()),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          final name = controller.text.trim(); if (name.isEmpty) return;
          final created = await state.addCategory(name: name, type: type, iconKey: iconKey, colorValue: color.toARGB32());
          if (context.mounted) Navigator.pop(context, created);
        }, child: const Text('Crea categoria'))),
      ])),
    )),
  );
  controller.dispose();
  return result;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});
  final String title; final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), if (trailing != null) trailing!]),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.title, required this.subtitle, this.action, super.key});
  final IconData icon; final String title; final String subtitle; final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Column(children: [Icon(icon, size: 38, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium), if (action != null) ...[const SizedBox(height: 16), action!]]),
  );
}

class FlatMetric extends StatelessWidget {
  const FlatMetric({required this.label, required this.value, this.icon, this.color, this.onTap, super.key});
  final String label; final String value; final IconData? icon; final Color? color; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    minVerticalPadding: 10,
    contentPadding: EdgeInsets.zero,
    leading: icon == null ? null : Icon(icon, color: color),
    title: Text(label),
    trailing: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
    onTap: onTap,
  );
}
