import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';

class ProductSellerSection extends StatelessWidget {
  final String sellerId;
  final String sellerName;
  const ProductSellerSection({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.push(
          AppRoutes.sellerWall,
          extra: {'sellerId': sellerId, 'sellerName': sellerName},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final profile = (data['profileImage'] ?? '').toString();
            final totalSales = data['totalSales'] ?? 0;
            final isVerified = data['isVerified'] == true;
            final avgRating = (data['avgRating'] as num?)?.toDouble() ?? 0.0;
            final reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;

            return Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.surfaceContainerHighest,
                  backgroundImage:
                      profile.isNotEmpty ? NetworkImage(profile) : null,
                  child: profile.isEmpty
                      ? const Icon(Icons.store, size: 14)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + verified badge
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              sellerName,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              color: Theme.of(context).colorScheme.primary,
                              size: 13,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            "$totalSales Sales",
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          if (reviewCount > 0) ...[
                            Text(
                              '  •  ',
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant, fontSize: 11),
                            ),
                            Icon(Icons.star_rounded,
                                size: 13, color: Colors.amber.shade600),
                            const SizedBox(width: 2),
                            Text(
                              '$avgRating ($reviewCount)',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
