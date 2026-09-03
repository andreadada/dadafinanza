import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

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

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
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
