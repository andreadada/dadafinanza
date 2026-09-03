import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

String money(double value, {bool signed = false}) {
  final formatter = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );
  final base = formatter.format(value.abs());
  if (!signed || value == 0) return base;
  return '${value > 0 ? '+' : '-'}$base';
}

class CategoryIconOption {
  const CategoryIconOption(this.key, this.icon, this.label);

  final String key;
  final IconData icon;
  final String label;
}

const categoryIconOptions = <CategoryIconOption>[
  CategoryIconOption('category', Icons.category_rounded, 'Generica'),
  CategoryIconOption('cart', Icons.shopping_cart_rounded, 'Spesa'),
  CategoryIconOption('grocery', Icons.local_grocery_store_rounded, 'Supermercato'),
  CategoryIconOption('restaurant', Icons.restaurant_rounded, 'Ristorante'),
  CategoryIconOption('coffee', Icons.local_cafe_rounded, 'Caffè'),
  CategoryIconOption('fastfood', Icons.fastfood_rounded, 'Fast food'),
  CategoryIconOption('bar', Icons.local_bar_rounded, 'Bar'),
  CategoryIconOption('home', Icons.home_rounded, 'Casa'),
  CategoryIconOption('chair', Icons.chair_rounded, 'Arredo'),
  CategoryIconOption('car', Icons.directions_car_rounded, 'Auto'),
  CategoryIconOption('bus', Icons.directions_bus_rounded, 'Bus'),
  CategoryIconOption('train', Icons.train_rounded, 'Treno'),
  CategoryIconOption('bike', Icons.directions_bike_rounded, 'Bici'),
  CategoryIconOption('flight', Icons.flight_rounded, 'Viaggi'),
  CategoryIconOption('fuel', Icons.local_gas_station_rounded, 'Carburante'),
  CategoryIconOption('parking', Icons.local_parking_rounded, 'Parcheggio'),
  CategoryIconOption('health', Icons.health_and_safety_rounded, 'Salute'),
  CategoryIconOption('pharmacy', Icons.local_pharmacy_rounded, 'Farmacia'),
  CategoryIconOption('fitness', Icons.fitness_center_rounded, 'Palestra'),
  CategoryIconOption('sport', Icons.sports_soccer_rounded, 'Sport'),
  CategoryIconOption('movie', Icons.movie_rounded, 'Cinema'),
  CategoryIconOption('music', Icons.music_note_rounded, 'Musica'),
  CategoryIconOption('gaming', Icons.sports_esports_rounded, 'Gaming'),
  CategoryIconOption('luggage', Icons.luggage_rounded, 'Vacanze'),
  CategoryIconOption('hotel', Icons.hotel_rounded, 'Hotel'),
  CategoryIconOption('school', Icons.school_rounded, 'Studio'),
  CategoryIconOption('book', Icons.menu_book_rounded, 'Libri'),
  CategoryIconOption('pets', Icons.pets_rounded, 'Animali'),
  CategoryIconOption('gift', Icons.card_giftcard_rounded, 'Regali'),
  CategoryIconOption('child', Icons.child_care_rounded, 'Bambini'),
  CategoryIconOption('clothes', Icons.checkroom_rounded, 'Vestiti'),
  CategoryIconOption('beauty', Icons.content_cut_rounded, 'Cura persona'),
  CategoryIconOption('tools', Icons.construction_rounded, 'Attrezzi'),
  CategoryIconOption('repair', Icons.build_rounded, 'Riparazioni'),
  CategoryIconOption('phone', Icons.phone_android_rounded, 'Telefono'),
  CategoryIconOption('wifi', Icons.wifi_rounded, 'Internet'),
  CategoryIconOption('subscriptions', Icons.language_rounded, 'Abbonamenti'),
  CategoryIconOption('bills', Icons.receipt_long_rounded, 'Bollette'),
  CategoryIconOption('electricity', Icons.bolt_rounded, 'Energia'),
  CategoryIconOption('water', Icons.water_drop_rounded, 'Acqua'),
  CategoryIconOption('cash', Icons.payments_rounded, 'Contanti'),
  CategoryIconOption('card', Icons.credit_card_rounded, 'Carta'),
  CategoryIconOption('bank', Icons.account_balance_rounded, 'Banca'),
  CategoryIconOption('salary', Icons.work_rounded, 'Stipendio'),
  CategoryIconOption('business', Icons.business_center_rounded, 'Lavoro'),
  CategoryIconOption('savings', Icons.savings_rounded, 'Risparmi'),
  CategoryIconOption('investment', Icons.trending_up_rounded, 'Investimenti'),
  CategoryIconOption('shopping', Icons.shopping_bag_rounded, 'Shopping'),
  CategoryIconOption('charity', Icons.volunteer_activism_rounded, 'Donazioni'),
  CategoryIconOption('event', Icons.event_rounded, 'Eventi'),
  CategoryIconOption('palette', Icons.palette_rounded, 'Hobby'),
  CategoryIconOption('camera', Icons.photo_camera_rounded, 'Foto'),
  CategoryIconOption('cleaning', Icons.cleaning_services_rounded, 'Pulizie'),
];

const categoryPalette = <Color>[
  Color(0xFF8E8E93),
  Color(0xFF6B7280),
  Color(0xFF7C8CF8),
  Color(0xFF5B9CF6),
  Color(0xFF65B8D8),
  Color(0xFFE07A5F),
  Color(0xFFED6A7A),
  Color(0xFFC77DFF),
  Color(0xFFD28C45),
  Color(0xFFF4F4F5),
];

IconData categoryIcon(String key) {
  for (final option in categoryIconOptions) {
    if (option.key == key) return option.icon;
  }
  return Icons.category_rounded;
}

Color transactionColor(BuildContext context, TransactionType type) => switch (type) {
      TransactionType.expense => const Color(0xFFFF7A7A),
      TransactionType.income => const Color(0xFF7CA7FF),
      TransactionType.transfer => const Color(0xFFD4D4D8),
    };

Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Elimina',
}) async {
  return await showDialog<bool>(
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
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

Future<Category?> showCategoryCreator(
  BuildContext context,
  AppState state, {
  TransactionType initialType = TransactionType.expense,
  bool lockType = false,
}) async {
  final controller = TextEditingController();
  var type = initialType;
  var iconKey = categoryIconOptions.first.key;
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
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      initialType == TransactionType.income
                          ? 'Nuova categoria entrata'
                          : initialType == TransactionType.expense
                              ? 'Nuova categoria spesa'
                              : 'Nuova categoria',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome categoria',
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
              const Text('Colore', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(categoryPalette.length, (index) {
                  final item = categoryPalette[index];
                  final selected = item == color;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: 'Colore ${index + 1}',
                    child: InkWell(
                      onTap: () => setSheetState(() => color = item),
                      customBorder: const CircleBorder(),
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
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: item.computeLuminance() > .6
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Icona', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Text(
                    '${categoryIconOptions.length} disponibili',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: categoryIconOptions.length,
                  itemBuilder: (context, index) {
                    final option = categoryIconOptions[index];
                    final selected = option.key == iconKey;
                    return Tooltip(
                      message: option.label,
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: option.label,
                        child: InkWell(
                          onTap: () => setSheetState(() => iconKey = option.key),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: .12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              option.icon,
                              color: selected ? Colors.white : AppTheme.muted,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crea categoria'),
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
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
