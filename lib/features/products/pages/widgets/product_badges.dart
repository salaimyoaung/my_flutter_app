import 'package:flutter/material.dart';
import '../../../../data/models/product_model.dart';

class ProductBadges extends StatelessWidget {
  final Product product;
  const ProductBadges({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chips = <Widget>[];

    void addChip({
      required IconData icon,
      required String label,
      required Color bg,
      required Color fg,
      required String tooltip,
    }) {
      final child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      );
      chips.add(Tooltip(message: tooltip, child: child));
    }

    if (product.effectiveBadgeRecommended) {
      addChip(
        icon: Icons.check_circle,
        label: "Recommended",
        bg: scheme.primaryContainer,
        fg: scheme.onPrimaryContainer,
        tooltip:
            "Condition and seller track record meet recommended criteria.",
      );
    }
    if (product.effectiveBadgeTrusted) {
      addChip(
        icon: Icons.verified_user,
        label: "Trusted Seller",
        bg: scheme.secondaryContainer,
        fg: scheme.onSecondaryContainer,
        tooltip: "Seller is trusted or has a strong order history.",
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}
