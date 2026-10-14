import 'package:flutter/material.dart';

class ProductPriceSection extends StatelessWidget {
  final double price;
  final double? originalPrice;

  const ProductPriceSection({
    super.key,
    required this.price,
    this.originalPrice,
  });

  // ✅ Centralized format — consistent with Product.formattedPrice getter
  static String formatPrice(double value) {
    final number = value.toInt();
    final formatted = number
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '$formatted Ks';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // ✅ originalPrice! > price — avoids floating point equality issue
    final hasDiscount = originalPrice != null &&
        originalPrice! > 0 &&
        originalPrice! > price;

    // ✅ Discount percentage — shown when discount exists
    final discountPercent = hasDiscount
        ? ((originalPrice! - price) / originalPrice! * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Original Price (struck through) ────────────────────────────
        if (hasDiscount) ...[
          Row(
            children: [
              Icon(Icons.close, color: scheme.error, size: 16),
              const SizedBox(width: 6),
              // ✅ Flexible — prevents overflow on small screens with long prices
              Flexible(
                child: Text(
                  '${formatPrice(originalPrice!)} (original)',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: scheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ✅ Discount badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '-$discountPercent%',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        // ── Current Price ───────────────────────────────────────────────
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: scheme.primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            // ✅ Flexible — prevents overflow on small screens
            Flexible(
              child: Text(
                hasDiscount
                    ? '${formatPrice(price)} (discount)'
                    : formatPrice(price),
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  // ✅ scheme.primary instead of hardcoded Colors.green
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}