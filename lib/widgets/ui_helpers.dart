import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

export '../theme/app_theme.dart';

String moneyValue(
  double value, {
  String currency = 'EUR',
  bool showCents = true,
  bool signed = false,
}) {
  final formatter = NumberFormat.currency(
    locale: 'it_IT',
    name: currency,
    decimalDigits: showCents ? 2 : 0,
  );
  final base = formatter.format(value.abs());
  if (!signed || value == 0) return base;
  return '${value > 0 ? '+' : '-'}$base';
}

String moneyFor(AppState state, double value, {bool signed = false}) =>
    moneyValue(
      value,
      currency: state.currency,
      showCents: state.showCents,
      signed: signed,
    );
String money(double value, {bool signed = false}) =>
    moneyValue(value, signed: signed);

class IconOption {
  const IconOption(this.key, this.icon, this.label, {this.group = 'Altro'});
  final String key;
  final IconData icon;
  final String label;
  final String group;
}

const categoryIconOptions = <IconOption>[
  IconOption(
    'category',
    Icons.category_rounded,
    'Generica',
    group: 'Quotidiano',
  ),
  IconOption('home', Icons.home_rounded, 'Casa', group: 'Quotidiano'),
  IconOption('cart', Icons.shopping_cart_rounded, 'Spesa', group: 'Quotidiano'),
  IconOption(
    'grocery',
    Icons.local_grocery_store_rounded,
    'Supermercato',
    group: 'Quotidiano',
  ),
  IconOption(
    'restaurant',
    Icons.restaurant_rounded,
    'Ristorante',
    group: 'Quotidiano',
  ),
  IconOption(
    'coffee',
    Icons.local_cafe_rounded,
    'Bar e caffè',
    group: 'Quotidiano',
  ),
  IconOption('bar', Icons.local_bar_rounded, 'Bar', group: 'Quotidiano'),
  IconOption(
    'fastfood',
    Icons.fastfood_rounded,
    'Fast food',
    group: 'Quotidiano',
  ),
  IconOption(
    'bakery',
    Icons.bakery_dining_rounded,
    'Panetteria',
    group: 'Quotidiano',
  ),
  IconOption(
    'laundry',
    Icons.local_laundry_service_rounded,
    'Lavanderia',
    group: 'Quotidiano',
  ),
  IconOption(
    'cleaning',
    Icons.cleaning_services_rounded,
    'Pulizie',
    group: 'Quotidiano',
  ),
  IconOption(
    'furniture',
    Icons.chair_rounded,
    'Arredamento',
    group: 'Quotidiano',
  ),
  IconOption('bed', Icons.bed_rounded, 'Camera', group: 'Quotidiano'),
  IconOption('kitchen', Icons.kitchen_rounded, 'Cucina', group: 'Quotidiano'),
  IconOption('garden', Icons.yard_rounded, 'Giardino', group: 'Quotidiano'),

  IconOption(
    'car',
    Icons.directions_car_rounded,
    'Auto',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'fuel',
    Icons.local_gas_station_rounded,
    'Benzina',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'bus',
    Icons.directions_bus_rounded,
    'Autobus',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'train',
    Icons.train_rounded,
    'Treno',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'subway',
    Icons.subway_rounded,
    'Metro',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'taxi',
    Icons.local_taxi_rounded,
    'Taxi',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'bike',
    Icons.directions_bike_rounded,
    'Bici',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'motorbike',
    Icons.two_wheeler_rounded,
    'Moto',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'flight',
    Icons.flight_rounded,
    'Volo',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'travel',
    Icons.luggage_rounded,
    'Viaggio',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'hotel',
    Icons.hotel_rounded,
    'Hotel',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'map',
    Icons.map_rounded,
    'Escursione',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'boat',
    Icons.sailing_rounded,
    'Barca',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'parking',
    Icons.local_parking_rounded,
    'Parcheggio',
    group: 'Trasporti e viaggi',
  ),
  IconOption(
    'toll',
    Icons.toll_rounded,
    'Pedaggio',
    group: 'Trasporti e viaggi',
  ),

  IconOption(
    'health',
    Icons.favorite_rounded,
    'Salute',
    group: 'Salute e persona',
  ),
  IconOption(
    'pharmacy',
    Icons.local_pharmacy_rounded,
    'Farmacia',
    group: 'Salute e persona',
  ),
  IconOption(
    'medical',
    Icons.medical_services_rounded,
    'Medico',
    group: 'Salute e persona',
  ),
  IconOption(
    'safety',
    Icons.health_and_safety_rounded,
    'Prevenzione',
    group: 'Salute e persona',
  ),
  IconOption(
    'fitness',
    Icons.fitness_center_rounded,
    'Palestra',
    group: 'Salute e persona',
  ),
  IconOption(
    'sport',
    Icons.sports_soccer_rounded,
    'Calcio',
    group: 'Salute e persona',
  ),
  IconOption(
    'running',
    Icons.directions_run_rounded,
    'Corsa',
    group: 'Salute e persona',
  ),
  IconOption('spa', Icons.spa_rounded, 'Benessere', group: 'Salute e persona'),
  IconOption(
    'mindfulness',
    Icons.self_improvement_rounded,
    'Relax',
    group: 'Salute e persona',
  ),
  IconOption(
    'hair',
    Icons.content_cut_rounded,
    'Parrucchiere',
    group: 'Salute e persona',
  ),
  IconOption(
    'beauty',
    Icons.face_retouching_natural_rounded,
    'Cura personale',
    group: 'Salute e persona',
  ),

  IconOption(
    'shopping',
    Icons.shopping_bag_rounded,
    'Shopping',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'clothes',
    Icons.checkroom_rounded,
    'Vestiti',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'tech',
    Icons.devices_rounded,
    'Tecnologia',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'gaming',
    Icons.sports_esports_rounded,
    'Videogiochi',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'movie',
    Icons.movie_rounded,
    'Cinema',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'streaming',
    Icons.ondemand_video_rounded,
    'Streaming',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'music',
    Icons.music_note_rounded,
    'Musica',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'books',
    Icons.menu_book_rounded,
    'Libri',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'photo',
    Icons.photo_camera_rounded,
    'Fotografia',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'art',
    Icons.palette_rounded,
    'Arte',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'party',
    Icons.celebration_rounded,
    'Festa',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'ticket',
    Icons.confirmation_number_rounded,
    'Biglietti',
    group: 'Shopping e tempo libero',
  ),
  IconOption(
    'toys',
    Icons.toys_rounded,
    'Giochi',
    group: 'Shopping e tempo libero',
  ),

  IconOption(
    'school',
    Icons.school_rounded,
    'Scuola',
    group: 'Lavoro e formazione',
  ),
  IconOption(
    'university',
    Icons.account_balance_rounded,
    'Università',
    group: 'Lavoro e formazione',
  ),
  IconOption(
    'work',
    Icons.work_rounded,
    'Lavoro',
    group: 'Lavoro e formazione',
  ),
  IconOption(
    'freelance',
    Icons.laptop_mac_rounded,
    'Freelance',
    group: 'Lavoro e formazione',
  ),
  IconOption(
    'business',
    Icons.business_center_rounded,
    'Business',
    group: 'Lavoro e formazione',
  ),
  IconOption(
    'course',
    Icons.co_present_rounded,
    'Corso',
    group: 'Lavoro e formazione',
  ),
  IconOption(
    'stationery',
    Icons.edit_note_rounded,
    'Cancelleria',
    group: 'Lavoro e formazione',
  ),
  IconOption(
    'print',
    Icons.print_rounded,
    'Stampa',
    group: 'Lavoro e formazione',
  ),

  IconOption(
    'gift',
    Icons.card_giftcard_rounded,
    'Regalo',
    group: 'Famiglia e social',
  ),
  IconOption('pets', Icons.pets_rounded, 'Animali', group: 'Famiglia e social'),
  IconOption(
    'family',
    Icons.groups_rounded,
    'Famiglia',
    group: 'Famiglia e social',
  ),
  IconOption(
    'child',
    Icons.child_care_rounded,
    'Bambini',
    group: 'Famiglia e social',
  ),
  IconOption(
    'birthday',
    Icons.cake_rounded,
    'Compleanno',
    group: 'Famiglia e social',
  ),
  IconOption(
    'charity',
    Icons.volunteer_activism_rounded,
    'Donazione',
    group: 'Famiglia e social',
  ),
  IconOption(
    'friends',
    Icons.people_alt_rounded,
    'Amici',
    group: 'Famiglia e social',
  ),
  IconOption(
    'wedding',
    Icons.favorite_border_rounded,
    'Cerimonia',
    group: 'Famiglia e social',
  ),

  IconOption(
    'bills',
    Icons.receipt_long_rounded,
    'Bollette',
    group: 'Utenze e casa',
  ),
  IconOption(
    'phone',
    Icons.phone_android_rounded,
    'Telefono',
    group: 'Utenze e casa',
  ),
  IconOption(
    'internet',
    Icons.wifi_rounded,
    'Internet',
    group: 'Utenze e casa',
  ),
  IconOption(
    'electricity',
    Icons.electric_bolt_rounded,
    'Elettricità',
    group: 'Utenze e casa',
  ),
  IconOption(
    'water',
    Icons.water_drop_rounded,
    'Acqua',
    group: 'Utenze e casa',
  ),
  IconOption(
    'gas',
    Icons.local_fire_department_rounded,
    'Gas',
    group: 'Utenze e casa',
  ),
  IconOption(
    'insurance',
    Icons.shield_rounded,
    'Assicurazione',
    group: 'Utenze e casa',
  ),
  IconOption(
    'tax',
    Icons.request_quote_rounded,
    'Tasse',
    group: 'Utenze e casa',
  ),
  IconOption(
    'repair',
    Icons.home_repair_service_rounded,
    'Riparazioni',
    group: 'Utenze e casa',
  ),
  IconOption(
    'construction',
    Icons.construction_rounded,
    'Lavori casa',
    group: 'Utenze e casa',
  ),
  IconOption(
    'security',
    Icons.security_rounded,
    'Sicurezza',
    group: 'Utenze e casa',
  ),

  IconOption(
    'salary',
    Icons.payments_rounded,
    'Stipendio',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'investment',
    Icons.trending_up_rounded,
    'Investimento',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'interest',
    Icons.percent_rounded,
    'Interessi',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'refund',
    Icons.replay_rounded,
    'Rimborso',
    group: 'Finanza e entrate',
  ),
  IconOption('sale', Icons.sell_rounded, 'Vendita', group: 'Finanza e entrate'),
  IconOption(
    'saving',
    Icons.savings_rounded,
    'Risparmio',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'exchange',
    Icons.currency_exchange_rounded,
    'Cambio valuta',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'cash',
    Icons.attach_money_rounded,
    'Denaro',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'wallet',
    Icons.account_balance_wallet_rounded,
    'Portafoglio',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'invoice',
    Icons.receipt_rounded,
    'Fattura',
    group: 'Finanza e entrate',
  ),
  IconOption(
    'bonus',
    Icons.redeem_rounded,
    'Bonus',
    group: 'Finanza e entrate',
  ),

  IconOption('event', Icons.event_rounded, 'Evento', group: 'Altro'),
  IconOption(
    'subscription',
    Icons.autorenew_rounded,
    'Abbonamento',
    group: 'Altro',
  ),
  IconOption('cloud', Icons.cloud_outlined, 'Servizi cloud', group: 'Altro'),
  IconOption('more', Icons.more_horiz_rounded, 'Altro', group: 'Altro'),
  IconOption('other', Icons.more_horiz_rounded, 'Generico', group: 'Altro'),
];

const accountIconOptions = <IconOption>[
  IconOption(
    'wallet',
    Icons.account_balance_wallet_rounded,
    'Portafoglio',
    group: 'Uso quotidiano',
  ),
  IconOption(
    'cash',
    Icons.payments_rounded,
    'Contanti',
    group: 'Uso quotidiano',
  ),
  IconOption(
    'coins',
    Icons.monetization_on_rounded,
    'Monete',
    group: 'Uso quotidiano',
  ),
  IconOption(
    'pocket',
    Icons.wallet_rounded,
    'Portamonete',
    group: 'Uso quotidiano',
  ),

  IconOption(
    'bank',
    Icons.account_balance_rounded,
    'Banca',
    group: 'Banche e carte',
  ),
  IconOption(
    'card',
    Icons.credit_card_rounded,
    'Carta',
    group: 'Banche e carte',
  ),
  IconOption(
    'prepaid',
    Icons.payment_rounded,
    'Prepagata',
    group: 'Banche e carte',
  ),
  IconOption(
    'checking',
    Icons.account_balance_wallet_outlined,
    'Conto corrente',
    group: 'Banche e carte',
  ),
  IconOption(
    'online_bank',
    Icons.language_rounded,
    'Banca online',
    group: 'Banche e carte',
  ),

  IconOption(
    'savings',
    Icons.savings_rounded,
    'Risparmio',
    group: 'Risparmio e investimenti',
  ),
  IconOption(
    'safe',
    Icons.lock_rounded,
    'Cassaforte',
    group: 'Risparmio e investimenti',
  ),
  IconOption(
    'investment',
    Icons.show_chart_rounded,
    'Investimenti',
    group: 'Risparmio e investimenti',
  ),
  IconOption(
    'portfolio',
    Icons.pie_chart_rounded,
    'Portafoglio investimenti',
    group: 'Risparmio e investimenti',
  ),
  IconOption(
    'crypto',
    Icons.currency_bitcoin_rounded,
    'Asset digitale',
    group: 'Risparmio e investimenti',
  ),
  IconOption(
    'goal',
    Icons.flag_rounded,
    'Obiettivo',
    group: 'Risparmio e investimenti',
  ),

  IconOption('home', Icons.home_work_rounded, 'Casa', group: 'Scopo'),
  IconOption(
    'business',
    Icons.business_center_rounded,
    'Business',
    group: 'Scopo',
  ),
  IconOption('travel', Icons.flight_takeoff_rounded, 'Viaggio', group: 'Scopo'),
  IconOption(
    'family_account',
    Icons.family_restroom_rounded,
    'Famiglia',
    group: 'Scopo',
  ),
  IconOption(
    'car_account',
    Icons.directions_car_rounded,
    'Auto',
    group: 'Scopo',
  ),
  IconOption(
    'education_account',
    Icons.school_rounded,
    'Studio',
    group: 'Scopo',
  ),

  IconOption('vault', Icons.security_rounded, 'Deposito', group: 'Altro'),
  IconOption(
    'archive_account',
    Icons.inventory_2_rounded,
    'Archivio',
    group: 'Altro',
  ),
  IconOption(
    'help',
    Icons.help_outline_rounded,
    'Non assegnato',
    group: 'Sistema',
  ),
];

const categoryPalette = <Color>[
  Color(0xFF8E8E93),
  Color(0xFF59636F),
  Color(0xFF5B78D4),
  Color(0xFF6C8DCB),
  Color(0xFFAF6C5A),
  Color(0xFFC65A67),
  Color(0xFF8C6FB1),
  Color(0xFFB47A43),
  Color(0xFF4F7A71),
  Color(0xFF6E6E73),
];

IconData _iconFor(String key, List<IconOption> options, IconData fallback) {
  for (final option in options) {
    if (option.key == key) return option.icon;
  }
  return fallback;
}

IconData categoryIcon(String key) =>
    _iconFor(key, categoryIconOptions, Icons.category_rounded);
IconData accountIcon(String key) =>
    _iconFor(key, accountIconOptions, Icons.account_balance_wallet_rounded);

Color transactionColor(BuildContext context, TransactionType type) =>
    switch (type) {
      TransactionType.expense => context.financeColors.negative,
      TransactionType.income => context.financeColors.positive,
      TransactionType.transfer => context.financeColors.neutral,
    };

Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Elimina',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> showIconPicker(
  BuildContext context, {
  required List<IconOption> options,
  required String selected,
}) async {
  final search = TextEditingController();
  var query = '';
  String? group;
  final groups = options.map((item) => item.group).toSet().toList();
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final normalized = query.trim().toLowerCase();
        final filtered = options.where((option) {
          final matchesGroup = group == null || option.group == group;
          final matchesSearch =
              normalized.isEmpty ||
              option.label.toLowerCase().contains(normalized) ||
              option.group.toLowerCase().contains(normalized);
          return matchesGroup && matchesSearch;
        }).toList();
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scegli icona',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Cerca icona o categoria',
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      FilterChip(
                        label: const Text('Tutte'),
                        selected: group == null,
                        onSelected: (_) => setState(() => group = null),
                      ),
                      const SizedBox(width: 7),
                      ...groups.expand(
                        (item) => [
                          FilterChip(
                            label: Text(item),
                            selected: group == item,
                            onSelected: (_) => setState(() => group = item),
                          ),
                          const SizedBox(width: 7),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${filtered.length} icone${group == null ? '' : ' · $group'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: .92,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final option = filtered[index];
                      final active = option.key == selected;
                      return Tooltip(
                        message: '${option.label} · ${option.group}',
                        child: Semantics(
                          button: true,
                          selected: active,
                          label: '${option.label}, ${option.group}',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context, option.key),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: active
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(option.icon, size: 26),
                                    const SizedBox(height: 5),
                                    Text(
                                      option.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  search.dispose();
  return result;
}

Future<Category?> showCategoryCreator(
  BuildContext context,
  AppState state, {
  TransactionType initialType = TransactionType.expense,
  bool lockType = false,
}) async {
  final controller = TextEditingController();
  var type = initialType;
  var iconKey = 'category';
  var color = categoryPalette.first;
  final result = await showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuova categoria',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Es. Benzina',
                ),
              ),
              if (!lockType) ...[
                const SizedBox(height: 16),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Spesa'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Entrata'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setSheetState(() => type = value.first),
                ),
              ],
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(iconKey)),
                title: const Text('Icona'),
                subtitle: const Text('Organizzate per tema e ricercabili'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final selected = await showIconPicker(
                    context,
                    options: categoryIconOptions,
                    selected: iconKey,
                  );
                  if (selected != null) {
                    setSheetState(() => iconKey = selected);
                  }
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryPalette
                    .map(
                      (item) => Semantics(
                        button: true,
                        selected: item == color,
                        label: 'Colore categoria',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setSheetState(() => color = item),
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: item,
                                  shape: BoxShape.circle,
                                ),
                                child: item == color
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    final created = await state.addCategory(
                      name: name,
                      type: type,
                      iconKey: iconKey,
                      colorValue: color.toARGB32(),
                    );
                    if (context.mounted) Navigator.pop(context, created);
                  },
                  child: const Text('Crea categoria'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.dispose();
  return result;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Column(
      children: [
        Icon(
          icon,
          size: 38,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class FlatMetric extends StatelessWidget {
  const FlatMetric({
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
    super.key,
  });
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minVerticalPadding: 10,
    contentPadding: EdgeInsets.zero,
    leading: icon == null ? null : Icon(icon, color: color),
    title: Text(label),
    trailing: Text(
      value,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
    ),
    onTap: onTap,
  );
}
