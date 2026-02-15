// products_page.dart
// FINAL CLEAN VERSION (compile-safe)
// DeviceType + Brand + Condition + Search
// Brand union from phone_models + products (auto updates when new product added)
// Admin actions included (Manage Models + Admin Orders)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/product_model.dart';
import '../../../app_features.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/services/admin_access_service.dart';
import 'package:flutter/foundation.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // ================= Device Types (Firestore values) =================
  static const String dtAll = "all";
  static const String dtAndroidPhone = "android_phone";
  static const String dtAndroidTablet = "android_tablet";
  static const String dtIphone = "iphone";
  static const String dtIpad = "ipad";

  final List<String> _deviceTypes = const [
    dtAll,
    dtAndroidPhone,
    dtAndroidTablet,
    dtIphone,
    dtIpad,
  ];

  Future<void> _toggleFavorite(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Favorite လုပ်ဖို့ Login ဝင်ပါ")),
      );
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(productId);

    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
      await AnalyticsService.logFavoriteAdd(productId: productId);
    }
  }

  String _selectedDeviceType = dtAll;

  String _deviceTypeLabel(String dt) {
    switch (dt) {
      case dtAndroidPhone:
        return "Android Phones";
      case dtAndroidTablet:
        return "Android Tablets";
      case dtIphone:
        return "iPhone";
      case dtIpad:
        return "iPad";
      default:
        return "All";
    }
  }

  // ================= Filters =================
  String _selectedBrand = "All";
  String _selectedCondition = "All";
  final List<int> _ramOptions = [4, 6, 8, 12];
  final List<int> _storageOptions = [64, 128, 256, 512, 1024];
  final List<String> _colorOptions = [
    "All",
    "Black",
    "White",
    "Blue",
    "Red",
    "Green",
    "Gold",
    "Silver",
    "Gray",
    "Space Black",
    "Midnight",
    "Starlight",
    "Purple",
  ];
  int? _filterRam;
  int? _filterStorage;
  String _filterColor = "All";
  String _filterSpecCondition = "All";
  int? _filterBatteryMin;
  int? _pendingStorage;
  String _pendingCondition = "All";

  final List<String> _conditions = const [
    "All",
    "Brand New",
    "Like New",
    "Used (Good)",
    "Used (Fair)",
  ];

  // ================= Search =================
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  String _q = "";
  bool _homeViewLogged = false;
  final Set<String> _impressionLogged = <String>{};

  void _enterSearch() => setState(() => _isSearching = true);

  void _exitSearch() {
    _searchCtrl.clear();
    setState(() {
      _q = "";
      _isSearching = false;
    });
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();

  // ================= Admin =================
  late Future<bool> _isAdminFuture;
  bool _isAdmin = false;

  Future<bool> _checkIsAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return AdminAccessService.instance.isAdmin(uid);
  }

  // ================= Brand caches (union) =================
  final Map<String, Set<String>> _brandsFromModels = {
    dtAndroidPhone: <String>{},
    dtAndroidTablet: <String>{},
    dtIphone: <String>{},
    dtIpad: <String>{},
  };

  final Map<String, Set<String>> _brandsFromProducts = {
    dtAndroidPhone: <String>{},
    dtAndroidTablet: <String>{},
    dtIphone: <String>{},
    dtIpad: <String>{},
  };

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _modelsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  final Set<String> _activeBrands = <String>{};
  final Map<String, int> _brandOrderByNorm = <String, int>{};
  final Map<String, String> _brandDisplayByNorm = <String, String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _brandsSub;

  StreamSubscription<User?>? _authSub;

  void _refreshAdminStatus() {
    if (!mounted) return;
    AdminAccessService.instance.clear();
    setState(() {
      _isAdminFuture = _checkIsAdmin();
    });
  }
  @override
  void dispose() {
    _authSub?.cancel();
    _brandsSub?.cancel();
    _modelsSub?.cancel();
    _productsSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ================= Firestore listeners =================
  String? _safeTypeOrNull(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s == dtAndroidPhone ||
        s == dtAndroidTablet ||
        s == dtIphone ||
        s == dtIpad) {
      return s;
    }
    return null; // ✅ deviceType မပါတာ / မမှန်တာ
  }


  @override
  void initState() {
    super.initState();
    _pendingStorage = _filterStorage;
    _pendingCondition = _selectedCondition;
    AdminAccessService.instance.clear();
    _isAdminFuture = _checkIsAdmin();
    _checkIsAdmin().then((v) {
      if (!mounted) return;
      setState(() => _isAdmin = v);
    });

    _listenActiveBrands();
    _listenModels();
    _listenProducts();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _refreshAdminStatus();
      _checkIsAdmin().then((v) {
        if (!mounted) return;
        setState(() => _isAdmin = v);
      });
    });
    if (!_homeViewLogged) {
      _homeViewLogged = true;
      AnalyticsService.logHomeView();
    }
  }

  void _listenActiveBrands() {
    _brandsSub?.cancel();
    _brandsSub = FirebaseFirestore.instance
        .collection('phone_brands')
        .where('active', isEqualTo: true)
        .orderBy('order')
        .orderBy('nameLower')
        .snapshots()
        .listen((snap) {
      _activeBrands.clear();
      _brandOrderByNorm.clear();
      _brandDisplayByNorm.clear();

      for (final d in snap.docs) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final key = _norm(name); // norm key
        final order = (data['order'] is int) ? (data['order'] as int) : 9999;

        _activeBrands.add(key);
        _brandOrderByNorm[key] = order;
        _brandDisplayByNorm[key] = name; // display name from phone_brands
      }

      if (mounted) setState(() {});
    }, onError: (e) => debugPrint("BRANDS_LISTEN_ERROR = $e"));
  }

  void _listenModels() {
    _modelsSub?.cancel();
    _modelsSub = FirebaseFirestore.instance
        .collection('phone_models')
        .snapshots()
        .listen((snap) {
          for (final k in _brandsFromModels.keys) {
            _brandsFromModels[k]!.clear();
          }

          for (final d in snap.docs) {
            final data = d.data();
            final v = data['active'];
            final isActive = (v is bool) ? v : true;
            if (!isActive) continue;

            final brand = (data['brand'] ?? '').toString().trim();
            if (brand.isEmpty) continue;

            final dt = _safeTypeOrNull(data['deviceType']);
            if (dt == null) continue; // ✅ deviceType မပါတာ skip
            _brandsFromModels[dt]!.add(brand);
          }

          if (mounted) setState(() {});
        }, onError: (e) => debugPrint("MODELS_LISTEN_ERROR = $e"));
  }

  void _listenProducts() {
    _productsSub?.cancel();
    _productsSub = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .listen((snap) {
          for (final k in _brandsFromProducts.keys) {
            _brandsFromProducts[k]!.clear();
          }
          bool hasRam = false;
          bool hasStorage = false;
          bool hasColor = false;

          for (final d in snap.docs) {
            final data = d.data();

            final brand = (data['brand'] ?? '').toString().trim();
            if (brand.isEmpty) continue;

            final dt = _safeTypeOrNull(data['deviceType']);
            if (dt == null) continue; // ✅ deviceType မပါတာ skip
            _brandsFromProducts[dt]!.add(brand);

            final specs = data['specs'];
            if (specs is Map<String, dynamic>) {
              if (specs.containsKey('ram') && specs['ram'] is int) hasRam = true;
              if (specs.containsKey('storage') && specs['storage'] is int) hasStorage = true;
              if (specs.containsKey('color') && (specs['color'] ?? '').toString().trim().isNotEmpty) hasColor = true;
            }
          }

          if (mounted) {
            setState(() {
              _hasSpecsRam = hasRam;
              _hasSpecsStorage = hasStorage;
              _hasSpecsColor = hasColor;
            });
          }
        }, onError: (e) => debugPrint("PRODUCTS_LISTEN_ERROR = $e"));
  }

  // ================= Brand union =================
  List<String> _brandsForSelectedType() {
    final set = <String>{};

    if (_selectedDeviceType == dtAll) {
      for (final t in _brandsFromModels.keys) {
        set.addAll(_brandsFromModels[t]!);
        set.addAll(_brandsFromProducts[t]!);
      }
    } else {
      set.addAll(_brandsFromModels[_selectedDeviceType]!);
      set.addAll(_brandsFromProducts[_selectedDeviceType]!);
    }

    // fallback: brands collection မ load သေးရင် a-z
    if (_activeBrands.isEmpty) {
      final list = set.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return ["All", ...list];
    }

    // active filter + order sort
    final list = set
        .where((b) => _activeBrands.contains(_norm(b)))
        .toList()
      ..sort((a, b) {
        final oa = _brandOrderByNorm[_norm(a)] ?? 9999;
        final ob = _brandOrderByNorm[_norm(b)] ?? 9999;
        if (oa != ob) return oa.compareTo(ob);
        // same order => nameLower sort
        final na = a.toLowerCase();
        final nb = b.toLowerCase();
        return na.compareTo(nb);
      });

    // display name ကို phone_brands ထဲက name နဲ့ ပြန်ထုတ် (clean)
    final display = list
        .map((b) => _brandDisplayByNorm[_norm(b)] ?? b)
        .toList();

    return ["All", ...display];
  }
  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _ensureFilterStateSafe();
    final showFilters = true;

    final brands = _brandsForSelectedType();
    if (_selectedBrand != "All" && !brands.contains(_selectedBrand)) {
      // safe reset if union changed
      _selectedBrand = "All";
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: "Search…",
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _q = v),
              )
            : Text("Home", style: AppTextStyles.heading(context)),
        actions: [
          // Search / Close
          if (_isSearching)
            IconButton(
              tooltip: "Close",
              icon: const Icon(Icons.close),
              onPressed: _exitSearch,
            )
          else
            IconButton(
              tooltip: "Search",
              icon: const Icon(Icons.search),
              onPressed: _enterSearch,
            ),

          // ✅ Search mode မဟုတ်မှ (normal mode) အောက်က buttons တွေပြ
          if (!_isSearching) ...[
            // ✅ Admin buttons (only admin sees)
            FutureBuilder<bool>(
              future: _isAdminFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                if (snap.data != true) return const SizedBox.shrink();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Manage Brands Order",
                      icon: const Icon(Icons.format_list_numbered),
                      onPressed: () {
                        context.push(AppRoutes.manageBrands);
                      },
                    ),
                    IconButton(
                      tooltip: "Manage Models",
                      icon: const Icon(Icons.settings_suggest_outlined),
                      onPressed: () {
                        context.push(AppRoutes.manageModels);
                      },
                    ),
                    IconButton(
                      tooltip: "Admin Orders",
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      onPressed: () {
                        context.push(AppRoutes.adminOrders);
                      },
                    ),
                  ],
                );
              },
            ),

            IconButton(
              tooltip: "Add Product",
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () {
                context.push(AppRoutes.addProduct);
              },
            ),
            IconButton(
              tooltip: "Notifications",
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                context.push(AppRoutes.notifications);
              },
            ),
            IconButton(
              tooltip: "My Orders",
              icon: const Icon(Icons.shopping_bag_outlined),
              onPressed: () {
                context.push(AppRoutes.buyerOrders);
              },
            ),
            IconButton(
              tooltip: "Seller Orders",
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () {
                context.push(AppRoutes.sellerOrders);
              },
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsQuery().snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }

          final docs = snap.data?.docs ?? [];
          final qN = _norm(_q);

          final items = docs.where((d) {
            return _matchesFilters(
              d.data(),
              selectedDeviceType: _selectedDeviceType,
              selectedBrand: _selectedBrand,
              selectedCondition: _selectedCondition,
              qN: qN,
              filtersActive: _filtersActive,
              filterRam: _filterRam,
              filterStorage: _filterStorage,
              filterColor: _filterColor,
              conditionBatteryActive: _conditionBatteryFiltersActive,
              filterSpecCondition: _filterSpecCondition,
              filterBatteryMin: _filterBatteryMin,
            );
          }).toList();

          return CustomScrollView(
            slivers: [
              if (showFilters)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 6),
                        _buildDeviceTypeChips(scheme),
                        const SizedBox(height: 8),
                        _buildBrandChips(scheme, brands),
                        if (_filtersActive) ...[
                          const SizedBox(height: 6),
                          _buildStorageChipsRow(
                            scheme,
                            value: _pendingStorage,
                            onChanged: (v) {
                              setState(() => _pendingStorage = v);
                              AnalyticsService.logFilterOptionChange(
                                type: 'storage',
                                value: v == null ? 'All' : '$v',
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildConditionChipsRow(
                            scheme,
                            value: _pendingCondition,
                            onChanged: (v) {
                              setState(() => _pendingCondition = v);
                              AnalyticsService.logFilterOptionChange(
                                type: 'condition',
                                value: v,
                              );
                            },
                          ),
                          if (_basicPendingChanged)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _filterStorage = _pendingStorage;
                                      _selectedCondition = _pendingCondition;
                                    });
                                    AnalyticsService.logFilterApply(
                                      selectedCount: _selectedFilterCount(
                                        storage: _pendingStorage,
                                        condition: _pendingCondition,
                                      ),
                                    );
                                  },
                                  child: const Text("Apply"),
                                ),
                              ),
                            ),
                        ],
                        if (_filtersActive &&
                            AppFeatures.ramFilterAdvancedEnabled)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _openAdvancedFilters(docs, qN),
                                icon: const Icon(Icons.tune),
                                label: const Text("More Filters"),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (docs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("Product မရှိသေးပါ")),
                )
              else if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("Result မတွေ့ပါ")),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final d = items[i];
                        final data = d.data();
                        final product = Product.fromFirestore(d.id, data);
                        if (!_impressionLogged.contains(product.id)) {
                          _impressionLogged.add(product.id);
                          AnalyticsService.logProductImpression(
                            productId: product.id,
                          );
                        }

                        final sellerName = (data['sellerName'] ?? '').toString();

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            AnalyticsService.logProductClick(
                              productId: product.id,
                            );
                            context.push(
                              AppRoutes.productPath(product.id),
                              extra: {
                                'product': product,
                                'sellerName': sellerName,
                              },
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: product.image.trim().isNotEmpty
                                              ? Image.network(
                                                  product.image,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: scheme.surfaceVariant,
                                                  child: const Center(
                                                    child: Icon(Icons.image),
                                                  ),
                                                ),
                                        ),

                                        // ❤️ Favorite button
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: uid == null
                                              ? _FavButton(
                                                  isFav: false,
                                                  onTap: () =>
                                                      _toggleFavorite(product.id),
                                                )
                                              : StreamBuilder<
                                                  DocumentSnapshot<Map<String, dynamic>>
                                                >(
                                                  stream: FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(uid)
                                                      .collection('favorites')
                                                      .doc(product.id)
                                                      .snapshots(),
                                                  builder: (context, favSnap) {
                                                    final isFav =
                                                        favSnap.data?.exists == true;
                                                    return _FavButton(
                                                      isFav: isFav,
                                                      onTap: () =>
                                                          _toggleFavorite(product.id),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.main(
                                            context,
                                          ).copyWith(fontWeight: FontWeight.w900),
                                        ),
                                        if (AppFeatures.productBadgesEnabled &&
                                            product.hasEffectiveBadge) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: _badgePills(product, scheme),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          product.price,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.small(
                                            context,
                                          ).copyWith(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Builder(builder: (context) {
                                          final cond = product.condition.trim();
                                          final b = product.batteryPercent;
                                          final hasSpecs = cond.isNotEmpty && b != null;
                                          final text = hasSpecs
                                              ? "$cond • Battery ${b}%"
                                              : "Not specified";
                                          return Text(
                                            text,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.small(context)
                                                .copyWith(color: scheme.onSurfaceVariant),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ================= Chips UI =================
  bool _hasSpecsRam = false;
  bool _hasSpecsStorage = false;
  bool _hasSpecsColor = false;
  bool get _filtersActive => AppFeatures.productFiltersEnabled || _isAdmin || kDebugMode;
  bool get _conditionBatteryFiltersActive =>
      AppFeatures.productConditionBatteryFilterEnabled;
  void _ensureFilterStateSafe() {
    if (!_filtersActive) {
      _filterRam = null;
      _filterStorage = null;
      _filterColor = "All";
      _pendingStorage = null;
      _pendingCondition = "All";
    }
    if (!AppFeatures.ramFilterAdvancedEnabled) {
      _filterRam = null;
    }
    if (!AppFeatures.colorFilterEnabled) {
      _filterColor = "All";
    }
    if (!_conditionBatteryFiltersActive) {
      _filterSpecCondition = "All";
      _filterBatteryMin = null;
    }
  }
  bool get _basicPendingChanged =>
      _pendingStorage != _filterStorage ||
      _pendingCondition != _selectedCondition;
  int _selectedFilterCount({
    int? storage,
    String? condition,
    int? ram,
  }) {
    var count = 0;
    final c = condition ?? _selectedCondition;
    final s = storage ?? _filterStorage;
    final r = ram ?? _filterRam;
    if (c != "All") count += 1;
    if (s != null) count += 1;
    if (AppFeatures.ramFilterAdvancedEnabled && r != null) count += 1;
    return count;
  }
  bool _matchesFilters(
    Map<String, dynamic> data, {
    required String selectedDeviceType,
    required String selectedBrand,
    required String selectedCondition,
    required String qN,
    required bool filtersActive,
    required int? filterRam,
    required int? filterStorage,
    required String filterColor,
    required bool conditionBatteryActive,
    required String filterSpecCondition,
    required int? filterBatteryMin,
  }) {
    final dt = _safeTypeOrNull(data['deviceType']);
    if (dt == null) return false;

    if (selectedDeviceType != dtAll && dt != selectedDeviceType) {
      return false;
    }

    final brand = (data['brand'] ?? '').toString().trim();
    if (selectedBrand != "All" && _norm(brand) != _norm(selectedBrand)) {
      return false;
    }

    final cond = (data['condition'] ?? '').toString().trim();
    if (selectedCondition != "All" && cond != selectedCondition) {
      return false;
    }

    if (qN.isNotEmpty) {
      final combined = _norm(
        "${data['brand']} ${data['model']} ${data['name']}",
      );
      if (!combined.contains(qN)) return false;
    }

    if (filtersActive) {
      final specs = data['specs'];
      if (AppFeatures.ramFilterAdvancedEnabled && filterRam != null) {
        if (specs is Map<String, dynamic> && specs['ram'] is int) {
          if (specs['ram'] != filterRam) return false;
        }
      }
      if (filterStorage != null) {
        if (specs is Map<String, dynamic> && specs['storage'] is int) {
          if (specs['storage'] != filterStorage) return false;
        }
      }
      if (AppFeatures.colorFilterEnabled && filterColor != "All") {
        if (specs is Map<String, dynamic> &&
            (specs['color'] ?? '').toString().trim().isNotEmpty) {
          final color = (specs['color'] ?? '').toString().trim();
          if (color != filterColor) return false;
        }
      }
    }

    if (conditionBatteryActive) {
      final specs = data['specs'];
      if (filterSpecCondition != "All") {
        if (specs is Map<String, dynamic>) {
          final v = specs['condition'];
          final c = (v ?? '').toString().trim();
          if (c.isNotEmpty && c != filterSpecCondition) {
            return false;
          }
        }
      }
      if (filterBatteryMin != null) {
        if (specs is Map<String, dynamic>) {
          final v = specs['batteryPercent'];
          final b = v is int ? v : int.tryParse((v ?? '').toString());
          if (b != null && b < filterBatteryMin) {
            return false;
          }
        }
      }
    }

    return true;
  }

  int _filteredCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String selectedDeviceType,
    required String selectedBrand,
    required String selectedCondition,
    required String qN,
    required bool filtersActive,
    required int? filterRam,
    required int? filterStorage,
    required String filterColor,
    required bool conditionBatteryActive,
    required String filterSpecCondition,
    required int? filterBatteryMin,
  }) {
    return docs.where((d) {
      return _matchesFilters(
        d.data(),
        selectedDeviceType: selectedDeviceType,
        selectedBrand: selectedBrand,
        selectedCondition: selectedCondition,
        qN: qN,
        filtersActive: filtersActive,
        filterRam: filterRam,
        filterStorage: filterStorage,
        filterColor: filterColor,
        conditionBatteryActive: conditionBatteryActive,
        filterSpecCondition: filterSpecCondition,
        filterBatteryMin: filterBatteryMin,
      );
    }).length;
  }

  Query<Map<String, dynamic>> _productsQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('products');
    if (!_filtersActive) return q;
    if (AppFeatures.ramFilterAdvancedEnabled && _filterRam != null && _hasSpecsRam) {
      q = q.where('specs.ram', isEqualTo: _filterRam);
    }
    if (_filterStorage != null && _hasSpecsStorage) {
      q = q.where('specs.storage', isEqualTo: _filterStorage);
    }
    if (AppFeatures.colorFilterEnabled && _filterColor != "All" && _hasSpecsColor) {
      q = q.where('specs.color', isEqualTo: _filterColor);
    }
    return q;
  }

  void _openAdvancedFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String qN,
  ) {
    if (!AppFeatures.ramFilterAdvancedEnabled) return;
    var tempRam = _filterRam;
    var tempColor = _filterColor;

    int countForTemp() {
      return _filteredCount(
        docs,
        selectedDeviceType: _selectedDeviceType,
        selectedBrand: _selectedBrand,
        selectedCondition: _selectedCondition,
        qN: qN,
        filtersActive: _filtersActive,
        filterRam: tempRam,
        filterStorage: _filterStorage,
        filterColor: tempColor,
        conditionBatteryActive: _conditionBatteryFiltersActive,
        filterSpecCondition: _filterSpecCondition,
        filterBatteryMin: _filterBatteryMin,
      );
    }

    var didApply = false;
    AnalyticsService.logFilterOpen();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final count = countForTemp();
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Filters",
                              style: AppTextStyles.heading(context),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempRam = null;
                                if (AppFeatures.colorFilterEnabled) {
                                  tempColor = "All";
                                }
                              });
                              AnalyticsService.logFilterClear();
                            },
                            child: const Text("Clear all"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_filtersActive)
                        ExpansionTile(
                          title: const Text("RAM"),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                right: 8,
                                bottom: 12,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ["All", ..._ramOptions.map((e) => "$e")].map((label) {
                                  final selected = (tempRam == null && label == "All") ||
                                      (tempRam != null && label == "$tempRam");
                                  return ChoiceChip(
                                    label: Text(label == "All" ? "All" : "$label GB"),
                                    selected: selected,
                                    onSelected: (_) {
                                      setSheetState(() {
                                        tempRam = label == "All" ? null : int.parse(label);
                                      });
                                      AnalyticsService.logFilterOptionChange(
                                        type: 'ram',
                                        value: label,
                                      );
                                    },
                                    showCheckmark: false,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      if (AppFeatures.colorFilterEnabled)
                        ExpansionTile(
                          title: const Text("Color"),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                right: 8,
                                bottom: 12,
                              ),
                              child: _buildColorDots(
                                scheme: Theme.of(context).colorScheme,
                                selectedColor: tempColor,
                                onSelected: (c) {
                                  setSheetState(() => tempColor = c);
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _filterRam = tempRam;
                                  if (AppFeatures.colorFilterEnabled) {
                                    _filterColor = tempColor;
                                  }
                                });
                                didApply = true;
                                AnalyticsService.logFilterApply(
                                  selectedCount: _selectedFilterCount(ram: tempRam),
                                );
                                Navigator.pop(context);
                              },
                              child: Text("Apply ($count)"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).then((_) {
      if (!didApply) {
        AnalyticsService.logFilterCancel();
      }
    });
  }

  Widget _buildColorDots({
    required ColorScheme scheme,
    required String selectedColor,
    required ValueChanged<String> onSelected,
  }) {
    final items = _colorOptions;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((label) {
        if (label == "All") {
          final selected = selectedColor == "All";
          return ChoiceChip(
            label: const Text("All"),
            selected: selected,
            onSelected: (_) => onSelected("All"),
            showCheckmark: false,
          );
        }
        final color = _colorFor(label);
        final selected = selectedColor == label;
        final isDark = color.computeLuminance() < 0.5;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onSelected(label),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: isDark ? Colors.white : Colors.black,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Color _colorFor(String name) {
    switch (name) {
      case "Black":
        return Colors.black;
      case "White":
        return Colors.white;
      case "Blue":
        return Colors.blue;
      case "Red":
        return Colors.red;
      case "Green":
        return Colors.green;
      case "Gold":
        return const Color(0xFFD4AF37);
      case "Silver":
        return const Color(0xFFC0C0C0);
      case "Gray":
        return Colors.grey;
      case "Space Black":
        return const Color(0xFF1C1C1E);
      case "Midnight":
        return const Color(0xFF1F2937);
      case "Starlight":
        return const Color(0xFFF2E8C9);
      case "Purple":
        return Colors.purple;
      default:
        return Colors.grey.shade400;
    }
  }

  Widget _buildDeviceTypeChips(ColorScheme scheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: _deviceTypes.map((dt) {
          final selected = dt == _selectedDeviceType;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_deviceTypeLabel(dt)),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedDeviceType = dt;
                  _selectedBrand = "All";
                });
              },
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
              backgroundColor: scheme.surface,
              selectedColor: scheme.primaryContainer,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandChips(ColorScheme scheme, List<String> brands) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: brands.map((b) {
          final selected = b == _selectedBrand;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(b),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedBrand = b;
                });
              },
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
              backgroundColor: scheme.surface,
              selectedColor: scheme.primaryContainer,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStorageChipsRow(
    ColorScheme scheme, {
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    final items = ["All", ..._storageOptions.map((e) => "$e").toList()];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: items.map((label) {
          final selected = (value == null && label == "All") ||
              (value != null && label == "$value");
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label == "All" ? "Storage: All" : "$label GB"),
              selected: selected,
              onSelected: (_) {
                onChanged(label == "All" ? null : int.parse(label));
              },
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
              backgroundColor: scheme.surface,
              selectedColor: scheme.primaryContainer,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConditionChipsRow(
    ColorScheme scheme, {
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: _conditions.map((c) {
          final selected = c == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c == "All" ? "Condition: All" : c),
              selected: selected,
              onSelected: (_) => onChanged(c),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
              backgroundColor: scheme.surface,
              selectedColor: scheme.primaryContainer,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }


  List<Widget> _badgePills(Product product, ColorScheme scheme) {
    final out = <Widget>[];
    if (product.effectiveBadgeRecommended) {
      out.add(_badgePill(
        scheme,
        icon: Icons.check_circle,
        label: "Recommended",
        bg: scheme.primaryContainer,
        fg: scheme.onPrimaryContainer,
      ));
    }
    if (product.effectiveBadgeTrusted) {
      out.add(_badgePill(
        scheme,
        icon: Icons.verified_user,
        label: "Trusted Seller",
        bg: scheme.secondaryContainer,
        fg: scheme.onSecondaryContainer,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.small(context).copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
class _FavButton extends StatelessWidget {
  const _FavButton({required this.isFav, required this.onTap});

  final bool isFav;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.black.withOpacity(0.5),
          child: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
