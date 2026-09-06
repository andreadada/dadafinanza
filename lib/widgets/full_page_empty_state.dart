import 'package:flutter/material.dart';

import 'ui_helpers.dart';

/// Empty state intended to be used as the entire body of a screen.
///
/// Unlike [EmptyState], which is deliberately compact for inline sections,
/// this widget centers its content in the available viewport while remaining
/// scrollable on short screens and with large accessibility text.
class FullPageEmptyState extends StatelessWidget {
  const FullPageEmptyState({
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: EmptyState(
              icon: icon,
              title: title,
              subtitle: subtitle,
              action: action,
            ),
          ),
        ),
      ),
    ),
  );
}
