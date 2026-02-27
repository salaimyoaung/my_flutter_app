// product_detail_page.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../app_features.dart';
import '../../../data/services/analytics_service.dart';
import '../../../core/router/app_navigator_keys.dart';
import '../../../data/models/product_model.dart';
import '../../../core/router/app_routes.dart';

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
  Product get product => widget.product;
  String get sellerName => widget.sellerName;
  bool _isAdmin = false;
  bool _overrideEnabled = false;
  bool _overrideRecommended = false;
  bool _overrideTrusted = false;
  String _overrideReason = "";
  final TextEditingController _overrideReasonCtrl = TextEditingController();
  bool _overrideDirty = false;
  bool _overrideSaving = false;
  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkIsAdmin();
  }

  @override
  void dispose() {
    final diff = DateTime.now().difference(_openedAt);
    if (diff.inSeconds < 3) {
      AnalyticsService.logQuickExit(
        productId: product.id,
        seconds: diff.inSeconds,
      );
    }
    _overrideReasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final String currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final String productUid = product.sellerId.trim();
    final bool isOwner = currentUid.isNotEmpty && currentUid == productUid;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        title: Text(
          product.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          Builder(
            builder: (context) {
              final user = FirebaseAuth.instance.currentUser;

              if (user == null) {
                return IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () => context.go(AppRoutes.signup),
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
                      color: isFav ? Colors.red : null,
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
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 360,
              child: ProductImageCarousel(
                images: product.images.isNotEmpty
                    ? product.images
                    : (product.coverImage.trim().isNotEmpty
                        ? [product.coverImage]
                        : (product.image.trim().isNotEmpty
                            ? [product.image]
                            : const [])),
                heroTag: "product-${product.id}",
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.heading(context).copyWith(fontSize: 24),
                  ),
                  if (AppFeatures.productBadgesEnabled &&
                      product.hasEffectiveBadge) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _badgePills(scheme),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(product.price, style: AppTextStyles.price().copyWith(fontSize: 20)),
                  const SizedBox(height: 10),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      context.push(
                        AppRoutes.sellerWall,
                        extra: {
                          'sellerId': product.sellerId,
                          'sellerName': sellerName,
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(product.sellerId)
                                .snapshots(),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const CircleAvatar(
                                  radius: 14,
                                  child: Icon(Icons.store, size: 14),
                                );
                              }

                              final profile =
                              (snap.data?.data()?['profileImage'] ?? '').toString();

                              return CircleAvatar(
                                radius: 14,
                                backgroundColor: scheme.surfaceVariant,
                                backgroundImage: profile.isNotEmpty
                                    ? NetworkImage(profile)
                                    : null,
                                child: profile.isEmpty
                                    ? const Icon(Icons.store, size: 14)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sellerName,
                              style: AppTextStyles.small(context).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 10),

                  Text(
                    "အမျိုးအစား - ${product.category}",
                    style: AppTextStyles.main(context).copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
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
                          "Specifications",
                          style: AppTextStyles.main(context)
                              .copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text("RAM")),
                            Text(
                              product.ram != null ? "${product.ram}GB" : "Not specified",
                              style: AppTextStyles.main(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: Text("Storage")),
                            Text(
                              product.storage != null ? "${product.storage}GB" : "Not specified",
                              style: AppTextStyles.main(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: Text("Color")),
                            Text(
                              product.color.trim().isNotEmpty ? product.color : "Not specified",
                              style: AppTextStyles.main(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: Text("Battery Health")),
                            Text(
                              product.batteryPercent != null
                                  ? "${product.batteryPercent}%"
                                  : "Not specified",
                              style: AppTextStyles.main(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: Text("Warranty")),
                            Text(
                              product.warrantyDays != null
                                  ? (product.warrantyDays == 0
                                      ? "No warranty"
                                      : "${product.warrantyDays} days")
                                  : "Not specified",
                              style: AppTextStyles.main(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: Text("Condition")),
                            Text(
                              product.condition.trim().isNotEmpty
                                  ? product.condition
                                  : "Not specified",
                              style: AppTextStyles.main(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isAdmin)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .doc(product.id)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData || snap.data == null) {
                          return const SizedBox.shrink();
                        }
                        final data = snap.data!.data() ?? <String, dynamic>{};
                        final p = Product.fromFirestore(product.id, data);
                        _syncOverrideFromProduct(p);
                        final badgeStatus = [
                          "Auto: ${p.badgeRecommended ? 'Recommended' : '-'}"
                              " / ${p.badgeTrusted ? 'Trusted' : '-'}",
                          p.badgeCalculatedAt != null
                              ? "Calculated: ${p.badgeCalculatedAt!.toDate()}"
                              : "Calculated: -",
                          p.badgeOverrideEnabled ? "Override: ON" : "Override: OFF",
                        ].join("\n");

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    "Badge Override (Admin)",
                                    style: AppTextStyles.main(context)
                                        .copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(badgeStatus, style: AppTextStyles.small(context)),
                                  const SizedBox(height: 10),
                                  SwitchListTile(
                                    value: _overrideEnabled,
                                    onChanged: (v) {
                                      setState(() {
                                        _overrideEnabled = v;
                                        _overrideDirty = true;
                                      });
                                    },
                                    title: const Text("Enable Override"),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  SwitchListTile(
                                    value: _overrideRecommended,
                                    onChanged: _overrideEnabled
                                        ? (v) {
                                            setState(() {
                                              _overrideRecommended = v;
                                              _overrideDirty = true;
                                            });
                                          }
                                        : null,
                                    title: const Text("Recommended"),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  SwitchListTile(
                                    value: _overrideTrusted,
                                    onChanged: _overrideEnabled
                                        ? (v) {
                                            setState(() {
                                              _overrideTrusted = v;
                                              _overrideDirty = true;
                                            });
                                          }
                                        : null,
                                    title: const Text("Trusted"),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  TextField(
                                    enabled: _overrideEnabled,
                                    controller: _overrideReasonCtrl,
                                    decoration: const InputDecoration(
                                      labelText: "Reason (required)",
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) {
                                      _overrideReason = v;
                                      _overrideDirty = true;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _overrideSaving
                                              ? null
                                              : () => _saveOverride(p),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: scheme.primary,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text("Save Override"),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _overrideSaving
                                              ? null
                                              : () => _disableOverride(p),
                                          child: const Text("Disable Override"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Badge Audit History",
                              style: AppTextStyles.main(context)
                                  .copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            _auditList(product.id),
                          ],
                        );
                      },
                    ),

                  // ✅ Call seller
                  ElevatedButton.icon(
                    onPressed: () => _callSeller(product.phone),
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: const Text(
                      "ရောင်းသူထံ ဖုန်းခေါ်ဆိုရန်",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✅ ONLY ONE BUTTON: Order Form (Escrow)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        context.go(AppRoutes.signup);
                        return;
                      }

                      // ✅ own product guard
                      if (product.sellerId.trim() == user.uid.trim()) {
                        _snack("ကိုယ့်ပစ္စည်းကို ကိုယ် Order မတင်နိုင်ပါ");
                        return;
                      }

                      context.push(
                        AppRoutes.orderForm,
                        extra: {
                          'product': product,
                          'sellerName': sellerName,
                        },
                      );
                    },
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: const Text("Order တင်မယ်", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showDeleteDialog(context),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text("ပစ္စည်းကိုဖျက်မည်", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _badgePills(ColorScheme scheme) {
    final out = <Widget>[];
    if (product.effectiveBadgeRecommended) {
      out.add(_badgePill(
        scheme,
        icon: Icons.check_circle,
        label: "Recommended",
        bg: scheme.primaryContainer,
        fg: scheme.onPrimaryContainer,
        tooltip: "Condition and seller track record meet recommended criteria.",
      ));
    }
    if (product.effectiveBadgeTrusted) {
      out.add(_badgePill(
        scheme,
        icon: Icons.verified_user,
        label: "Trusted Seller",
        bg: scheme.secondaryContainer,
        fg: scheme.onSecondaryContainer,
        tooltip: "Seller is trusted or has a strong order history.",
      ));
    }
    return out;
  }

  Widget _badgePill(
    ColorScheme scheme, {
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
            style: AppTextStyles.small(context).copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
    return Tooltip(message: tooltip, child: child);
  }

  void _snack(String msg) {
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _checkIsAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final role = (doc.data()?['role'] ?? '').toString().toLowerCase().trim();
    if (mounted) setState(() => _isAdmin = role == 'admin');
  }

  void _syncOverrideFromProduct(Product p) {
    if (_overrideDirty) return;
    _overrideEnabled = p.badgeOverrideEnabled;
    _overrideRecommended = p.badgeOverrideRecommended ?? false;
    _overrideTrusted = p.badgeOverrideTrusted ?? false;
    _overrideReason = p.badgeOverrideReason;
    _overrideReasonCtrl.text = _overrideReason;
  }

  Future<void> _saveOverride(Product p) async {
    if (!_overrideEnabled) {
      _snack("Enable override first");
      return;
    }
    if (_overrideReason.trim().isEmpty) {
      _snack("Reason required");
      return;
    }
    setState(() => _overrideSaving = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('adminSetProductBadgeOverride').call({
        'productId': p.id,
        'recommended': _overrideRecommended,
        'trusted': _overrideTrusted,
        'reason': _overrideReason.trim(),
      });
      _overrideDirty = false;
      _snack("Override saved");
    } catch (e) {
      _snack("Override error: $e");
    } finally {
      if (mounted) setState(() => _overrideSaving = false);
    }
  }

  Future<void> _disableOverride(Product p) async {
    setState(() => _overrideSaving = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('adminDisableProductBadgeOverride').call({
        'productId': p.id,
      });
      _overrideDirty = false;
      _snack("Override disabled");
    } catch (e) {
      _snack("Disable error: $e");
    } finally {
      if (mounted) setState(() => _overrideSaving = false);
    }
  }

  Widget _auditList(String productId) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('badge_audit_logs')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text("No audit logs");
        }
        return Column(
          children: docs.map((d) {
            final data = d.data();
            final adminName = (data['adminName'] ?? '').toString().trim();
            final action = (data['action'] ?? '').toString().trim();
            final reason = (data['reason'] ?? '').toString().trim();
            final ts = data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate().toString()
                : '';
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$action • $adminName", style: AppTextStyles.small(context)),
                  const SizedBox(height: 4),
                  Text(reason.isEmpty ? "-" : reason, style: AppTextStyles.small(context)),
                  const SizedBox(height: 4),
                  Text(ts, style: AppTextStyles.small(context)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _callSeller(String phoneRaw) async {
    final phone = phoneRaw.trim();
    if (phone.isEmpty) {
      _snack("ဖုန်းနံပါတ် မရှိပါ");
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (!await canLaunchUrl(uri)) {
      _snack("ဖုန်းခေါ်၍မရပါ");
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showDeleteDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text("ပစ္စည်းဖျက်ရန်", style: AppTextStyles.heading(context)),
        content: Text(
          "ဤပစ္စည်းကို အပြီးတိုင် ဖျက်မှာ သေချာပါသလား?",
          style: AppTextStyles.main(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("မဖျက်တော့ပါ"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(product.id).delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text("ဖျက်မည်", style: TextStyle(color: Colors.red)),
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

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final images = widget.images.where((e) => e.trim().isNotEmpty).toList();
    if (images.isEmpty) {
      return Hero(
        tag: widget.heroTag,
        child: Container(
          color: scheme.surfaceVariant,
          child: const Center(child: Icon(Icons.image, size: 48)),
        ),
      );
    }

    final currentUrl = images[_index.clamp(0, images.length - 1)];

    return Hero(
      tag: widget.heroTag,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image.network(
                currentUrl,
                key: ValueKey(currentUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: scheme.surfaceVariant,
                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: scheme.surfaceVariant,
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
                child: Container(
                  color: Colors.black.withOpacity(0.08),
                ),
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
                    Colors.black.withOpacity(0.25),
                    Colors.transparent,
                    Colors.black.withOpacity(0.18),
                  ],
                ),
              ),
            ),
          ),
          PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            itemCount: images.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
              });
            },
            itemBuilder: (context, i) {
              final imageUrl = images[i];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final page = _controller.hasClients
                      ? (_controller.page ?? _controller.initialPage.toDouble())
                      : _controller.initialPage.toDouble();
                  final distance = (page - i).abs();
                  final scale = (1 - (distance * 0.06)).clamp(0.94, 1.0);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: PhotoView(
                        imageProvider: NetworkImage(imageUrl),
                        backgroundDecoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2.5,
                        loadingBuilder: (context, event) {
                          return Container(
                            color: scheme.surfaceVariant,
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: scheme.surfaceVariant,
                          child: const Center(child: Icon(Icons.broken_image, size: 48)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
                    activeDotColor: Colors.white.withOpacity(0.9),
                    dotColor: Colors.white.withOpacity(0.35),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
