import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:sigmamoby/shared/pages/full_screen_image_page.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_features.dart';
import '../../../core/router/app_navigator_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/utils/require_login.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/admin_access_service.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/services/storage_service.dart';
import 'widgets/product_actions.dart';
import 'widgets/product_badges.dart';
import 'widgets/product_price_section.dart';
import 'widgets/product_seller_section.dart';
import 'widgets/product_specs_section.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  final String sellerName;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.sellerName,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Product _liveProduct;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _productSub;
  Product get product => _liveProduct;
  String get sellerName => widget.sellerName;

  bool _isAdmin = false;
  bool _deleting = false;

  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _liveProduct = widget.product;
    _checkIsAdmin();
    _productSub = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _liveProduct = Product.fromFirestore(widget.product.id, snap.data()!);
        });
      } else if (!snap.exists && mounted && !_deleting) {
        context.pop();
      }
    });
  }

  @override
  void dispose() {
    _productSub?.cancel();
    final diff = DateTime.now().difference(_openedAt);
    if (diff.inSeconds < 3) {
      AnalyticsService.logQuickExit(
        productId: product.id,
        seconds: diff.inSeconds,
      );
    }
    super.dispose();
  }

  void _snack(String msg) {
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _checkIsAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ok = await AdminAccessService.instance.isAdmin(uid);
    if (mounted) setState(() => _isAdmin = ok);
  }

  Future<void> _callSeller(String phoneRaw) async {
    final phone = phoneRaw.trim();
    if (phone.isEmpty) {
      _snack('ဖုန်းနံပါတ် မရှိပါ');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await canLaunchUrl(uri)) {
      _snack('ဖုန်းခေါ်၍မရပါ');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _chatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  Future<String> _createOrGetChat(String sellerId) async {
    final buyerId = FirebaseAuth.instance.currentUser?.uid;
    if (buyerId == null) throw Exception('Login required');

    final chatId = _chatId(buyerId, sellerId);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    final doc = await chatRef.get();
    if (!doc.exists) {
      await chatRef.set({
        'participants': [buyerId, sellerId],
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount': {buyerId: 0, sellerId: 0},
      });
    }
    return chatId;
  }

  void _showDeleteDialog(BuildContext context) {
    if (product.hasActiveOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order တင်ထားဆဲ ပစ္စည်းကို ဖျက်၍ မရပါ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (product.soldAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ရောင်းချပြီးသား ပစ္စည်းကို ဖျက်၍ မရပါ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('ပစ္စည်းဖျက်ရန်', style: textTheme.titleLarge),
        content: Text(
          'ဤပစ္စည်းကို အပြီးတိုင် ဖျက်မှာ သေချာပါသလား?',
          style: textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('မဖျက်တော့ပါ'),
          ),
          TextButton(
            onPressed: () async {
              setState(() => _deleting = true);
              final db = FirebaseFirestore.instance;
              final batch = db.batch();

              batch.delete(db.collection('products').doc(product.id));

              final imeiSnap = await db
                  .collection('imei_registry')
                  .where('productId', isEqualTo: product.id)
                  .get();
              for (final doc in imeiSnap.docs) {
                batch.delete(doc.reference);
              }

              await batch.commit();

              final allUrls = [
                ...product.images,
                if (product.imeiPhoto.isNotEmpty) product.imeiPhoto,
              ];
              if (allUrls.isNotEmpty) {
                await StorageService().deleteFiles(allUrls);
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ပစ္စည်းကို ဖျက်ပြီးပြီ')),
              );
              context.pop();
            },
            child: Text(
              'ဖျက်မည်',
              style: textTheme.labelLarge?.copyWith(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final extra = GoRouterState.of(context).extra as Map?;
    final productUid =
        ((extra?['sellerId'] ?? product.sellerId) as Object).toString().trim();
    final isOwner = currentUid.isNotEmpty && currentUid == productUid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(
        title: product.name,
        leading: const BackButton(),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () =>
                  context.push(AppRoutes.editProduct, extra: product),
            ),
          Builder(builder: (context) {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              return IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () => requireLogin(
                  context,
                  message: 'Favorite သိမ်းရန် login လိုအပ်သည်',
                  onAuthorized: () {},
                ),
              );
            }
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('favorites')
                  .doc(product.id)
                  .snapshots(),
              builder: (context, snapshot) {
                final isFav = snapshot.data?.exists ?? false;
                return IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.white,
                  ),
                  onPressed: () async {
                    final favRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('favorites')
                        .doc(product.id);
                    if (isFav) {
                      await favRef.delete();
                    } else {
                      await favRef.set({
                        'productId': product.id,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                  },
                );
              },
            );
          }),
        ],
      ),
      body: SingleChildScrollView(
        child: MaxWidthBox(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 360,
                child: ProductImageCarousel(
                  images: product.images.isNotEmpty
                      ? product.images
                      : [
                          if (product.coverImage.trim().isNotEmpty)
                            product.coverImage
                          else if (product.image.trim().isNotEmpty)
                            product.image,
                        ],
                  heroTag: 'product-${product.id}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: textTheme.headlineSmall?.copyWith(fontSize: 24),
                    ),
                    if (AppFeatures.productBadgesEnabled &&
                        product.hasEffectiveBadge) ...[
                      const SizedBox(height: 8),
                      ProductBadges(product: product),
                    ],
                    const SizedBox(height: 10),
                    ProductPriceSection(
                      price: product.priceDouble,
                      originalPrice: product.originalPriceDouble,
                    ),
                    const SizedBox(height: 10),
                    ProductSellerSection(
                      sellerId: product.sellerId,
                      sellerName: sellerName,
                    ),
                    const SizedBox(height: 20),
                    ProductSpecsSection(
                      product: product,
                      showVerification: false,
                    ),
                    if (product.imeiMasked.isNotEmpty) ...[
                      _ImeiStatusBadge(imeiStatus: product.imeiStatus),
                      const SizedBox(height: 10),
                      ProductVerificationSection(product: product),
                    ],
                    if (product.detail.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Details or Additional Accessories',
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ExpandableText(text: product.detail),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Builder(
                      builder: (context) {
                        final isLocked =
                            product.hasActiveOrder || !product.active;
                        if (isLocked && !isOwner && !_isAdmin) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color:
                                  scheme.errorContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 18, color: scheme.error),
                                const SizedBox(width: 8),
                                Text(
                                  'ဤပစ္စည်း Order တင်ပြီးဖြစ်နေသည်',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ProductActions(
                          isOwner: isOwner,
                          isAdmin: _isAdmin,
                          isSold: product.soldAt != null,
                          onCallSeller: () => requireLogin(
                            context,
                            message: 'Seller ကို ဆက်သွယ်ရန် login လိုအပ်သည်',
                            onAuthorized: () => _callSeller(product.phone),
                          ),
                          onChatSeller: () => requireLogin(
                            context,
                            message:
                                'Seller နှင့် chat ပြုလုပ်ရန် login လိုအပ်သည်',
                            onAuthorized: () async {
                              try {
                                final chatId =
                                    await _createOrGetChat(product.sellerId);
                                if (!mounted) return;
                                if (context.mounted) {
                                  context.push('/chat', extra: {
                                    'chatId': chatId,
                                    'otherUserId': product.sellerId,
                                  });
                                }
                              } catch (e) {
                                _snack(e
                                    .toString()
                                    .replaceAll('Exception: ', ''));
                              }
                            },
                          ),
                          onOrder: () async {
                            requireLogin(
                              context,
                              message: 'Order တင်ရန် login လိုအပ်သည်',
                              onAuthorized: () {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;
                                if (product.sellerId.trim() ==
                                    user.uid.trim()) {
                                  _snack('ကိုယ့်ပစ္စည်းကို ကိုယ် Order မတင်နိုင်ပါ');
                                  return;
                                }
                                if (mounted) {
                                  context.push(AppRoutes.orderForm, extra: {
                                    'product': product,
                                    'sellerName': sellerName,
                                  });
                                }
                              },
                            );
                          },
                          onDelete: () => _showDeleteDialog(context),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImeiStatusBadge extends StatelessWidget {
  final String imeiStatus;
  const _ImeiStatusBadge({required this.imeiStatus});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (imeiStatus == 'VALID') {
      return _badge(context, Icons.verified_outlined, 'IMEI Verified ✅',
          Colors.green.shade700, Colors.green.shade50);
    }
    if (imeiStatus == 'BLACKLISTED') {
      return _badge(context, Icons.block_outlined, 'IMEI Blacklisted 🚫',
          scheme.error, scheme.errorContainer);
    }
    return _badge(
        context,
        Icons.schedule_outlined,
        'IMEI Verification Pending ⏳',
        Colors.orange.shade700,
        Colors.orange.shade50);
  }

  Widget _badge(
    BuildContext context,
    IconData icon,
    String label,
    Color fgColor,
    Color bgColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fgColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ProductImageCarousel extends StatefulWidget {
  final List<String> images;
  final String heroTag;

  const ProductImageCarousel({
    super.key,
    required this.images,
    required this.heroTag,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  late final PageController _controller;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_controller.hasClients && widget.images.length > 1) {
        int nextIndex = (_index + 1) % widget.images.length;
        _controller.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final images = widget.images.where((e) => e.trim().isNotEmpty).toList();

    if (images.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image, size: 48)),
      );
    }

    final currentUrl = images[_index.clamp(0, images.length - 1)];

    return Stack(
      children: [
        // ── Blurred background ──────────────────────────────────────
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: AppNetworkImage(
              currentUrl,
              key: ValueKey(currentUrl),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: scheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: scheme.shadow.withValues(alpha: 0.08)),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.shadow.withValues(alpha: 0.25),
                  scheme.shadow.withValues(alpha: 0.0),
                  scheme.shadow.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),

        // ── Interactive PageView ──────────────────────────────────
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _timer?.cancel();
            } else if (notification is ScrollEndNotification) {
              _startTimer();
            }
            return false;
          },
          child: PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
            final imageUrl = images[i];

            // Standard hierarchy: ClipRRect -> AppNetworkImage
            Widget imageWidget = ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppNetworkImage(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.phone_android,
                  size: 48,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );

            // Wrap only the first image in Hero for list-to-detail transition
            if (i == 0) {
              imageWidget = Hero(
                tag: widget.heroTag,
                child: imageWidget,
              );
            }

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final page = _controller.hasClients
                    ? (_controller.page ??
                        _controller.initialPage.toDouble())
                    : _controller.initialPage.toDouble();
                final distance = (page - i).abs();
                final scale = (1 - (distance * 0.06)).clamp(0.94, 1.0);
                return Transform.scale(scale: scale, child: child);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: PhotoView.customChild(
                    onTapUp: (context, details, value) {
                      FullScreenImagePage.showGallery(
                        context,
                        images,
                        initialIndex: i,
                      );
                    },
                    backgroundDecoration: BoxDecoration(
                      color: scheme.shadow.withValues(alpha: 0.0),
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2.5,
                    child: imageWidget,
                  ),
                ),
              ),
            );
          },
        ),
      ),

        // ── Page Indicator ─────────────────────────────────────────
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: SmoothPageIndicator(
                controller: _controller,
                count: images.length,
                effect: WormEffect(
                  dotHeight: 7,
                  dotWidth: 7,
                  spacing: 6,
                  activeDotColor: scheme.onSurface.withValues(alpha: 0.9),
                  dotColor: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 4,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLong = widget.text.length > 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Text(
              widget.text,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? 'See less' : 'See more',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
