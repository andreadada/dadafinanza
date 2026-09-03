import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

String money(double value, {bool signed = false}) {
  final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);
  final base = formatter.format(value.abs());
  if (!signed || value == 0) return base;
  return '${value > 0 ? '+' : '-'}$base';
}

IconData categoryIcon(String key) => switch (key) {
      'nightlife' => Icons.local_bar_rounded,
      'bakery' => Icons.bakery_dining_rounded,
      'subscriptions' => Icons.language_rounded,
      'fastfood' => Icons.local_pizza_rounded,
      'bolt' => Icons.bolt_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'wallet' => Icons.account_balance_wallet_rounded,
      'home' => Icons.home_rounded,
      'car' => Icons.directions_car_rounded,
      'cart' => Icons.shopping_cart_rounded,
      'health' => Icons.health_and_safety_rounded,
      'book' => Icons.menu_book_rounded,
      'cash' => Icons.payments_rounded,
      'salary' => Icons.volunteer_activism_rounded,
      'help' => Icons.help_outline_rounded,
      'shield' => Icons.shield_outlined,
      'savings' => Icons.savings_rounded,
      _ => Icons.category_rounded,
    };

Color transactionColor(BuildContext context, TransactionType type) => switch (type) {
      TransactionType.expense => const Color(0xFFFF725E),
      TransactionType.income => const Color(0xFF27D398),
      TransactionType.transfer => Theme.of(context).colorScheme.primary,
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
