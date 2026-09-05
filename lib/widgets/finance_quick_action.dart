import 'package:flutter/material.dart';

class FinanceQuickAction extends StatelessWidget {
  const FinanceQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final base = color ?? Theme.of(context).colorScheme.onSurface;
    final resolvedColor = enabled ? base : base.withValues(alpha: .38);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: Tooltip(
        message: semanticLabel ?? label,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 23, color: resolvedColor),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: resolvedColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
