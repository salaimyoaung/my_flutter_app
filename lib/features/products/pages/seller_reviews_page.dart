import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/models/review_model.dart';
import '../../../data/services/review_service.dart';

class SellerReviewsPage extends StatelessWidget {
  final String sellerId;
  final String sellerName;

  const SellerReviewsPage({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: '$sellerName\'s Reviews',
      ),
      body: StreamBuilder<List<ReviewModel>>(
        stream: ReviewService.sellerReviewsStream(sellerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reviews = snap.data ?? [];
          if (reviews.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No reviews yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              return ReviewCard(review: reviews[index]);
            },
          );
        },
      ),
    );
  }
}

class ReviewCard extends StatefulWidget {
  final ReviewModel review;
  const ReviewCard({required this.review, super.key});
  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push(
                  AppRoutes.sellerWall,
                  extra: {'sellerId': r.buyerId, 'sellerName': r.buyerName},
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: r.buyerProfileImage.isNotEmpty 
                          ? NetworkImage(r.buyerProfileImage) 
                          : null,
                      child: r.buyerProfileImage.isEmpty 
                          ? const Icon(Icons.person, size: 20) 
                          : null,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push(
                    AppRoutes.sellerWall,
                    extra: {'sellerId': r.buyerId, 'sellerName': r.buyerName},
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.buyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(r.productName, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 14,
                    )),
                  ),
                  if (r.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatDate(r.createdAt!.toDate()),
                        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              r.comment,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (r.comment.length > 100)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'See less' : 'See more',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
