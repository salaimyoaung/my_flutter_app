import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/product_model.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import '../../../core/theme/app_colors.dart';

class ModelListingsPage extends StatefulWidget {
  final String brand;
  final String model;
  final String? sellerId;

  const ModelListingsPage({
    super.key,
    required this.brand,
    required this.model,
    this.sellerId,
  });

  @override
  State<ModelListingsPage> createState() => _ModelListingsPageState();
}

class _ModelListingsPageState extends State<ModelListingsPage> {
  final ScrollController _scrollController = ScrollController();
  
  // ✅ Persistent stream to prevent visual "flapping" during UI state changes
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _listingsStream;

  // ── Filters ────────────────────────────────────────────────────────────────
  String? _selCondition;
  String? _selStorage;
  String? _selRam;
  String? _selVersion;
  String? _selRom;
  String? _selColor;
  String? _selModelNumber;
  String  _sortBy = 'price_asc';
  bool    _filtersOpen = false;
  bool    _onlyVerified = false; // IMEI + Device verified filter

  // ── Expanded accordion items ───────────────────────────────────────────────
  final Set<String> _expanded = {};

  // ── Buyer city for local-first sort ───────────────────────────────────────
  String _buyerCity = '';

  @override
  void initState() {
    super.initState();
    _loadBuyerCity();
    _initStream();
  }

  void _initStream() {
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection('products')
        .where('brand',  isEqualTo: widget.brand)
        .where('model',  isEqualTo: widget.model)
        .where('active', isEqualTo: true);

    if (widget.sellerId != null) {
      ref = ref.where('sellerId', isEqualTo: widget.sellerId);
    }
    _listingsStream = ref.orderBy('price').snapshots();
  }

  Future<void> _loadBuyerCity() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final city = (doc.data()?['shopCity'] ?? '').toString().trim();
      if (mounted && city.isNotEmpty) setState(() => _buyerCity = city);
    } catch (_) {}
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isApple => widget.brand.toLowerCase() == 'apple';

  int get _activeFilterCount => [
    _selCondition, _selStorage, _selRam, _selVersion, _selRom,
    _selColor, _selModelNumber,
    if (_sortBy != 'price_asc') _sortBy,
    if (_onlyVerified) 'verified',
  ].whereType<String>().length;

  void _clearFilters() => setState(() {
    _selCondition = _selStorage = _selRam = _selVersion = _selRom =
        _selColor = _selModelNumber = null;
    _sortBy = 'price_asc';
    _onlyVerified = false;
  });

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _listingsStream,
            builder: (context, snap) {
              // ✅ Smart Loading: Only show spinner on FIRST load or when data is null.
              // Prevents the entire screen from flashing when local state (filters/expand) changes.
              if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const Center(child: Text('Something went wrong'));
              }

              final rawDocs = snap.data?.docs ?? [];

          // ── Dynamic Filter Options (Cascading) ───────────────────────────
          // Each dropdown's options are calculated by filtering rawDocs 
          // against all active filters *except* its own.

          bool matches(QueryDocumentSnapshot<Map<String, dynamic>> d, {String? skipKey}) {
            final data  = d.data();
            final specs = data['specs'] ?? {};
            String s(String k) => (specs[k] ?? '').toString().trim();
            String t(String k) => (data[k]  ?? '').toString().trim();

            if (skipKey != 'condition'   && _selCondition   != null && t('condition')   != _selCondition)   return false;
            if (skipKey != 'storage'     && _selStorage     != null && s('storage')     != _selStorage)     return false;
            if (skipKey != 'ram'         && _selRam         != null && s('ram')         != _selRam)         return false;
            if (skipKey != 'version'     && _selVersion     != null && s('version')     != _selVersion)     return false;
            if (skipKey != 'rom'         && _selRom         != null && s('rom')         != _selRom)         return false;
            if (skipKey != 'color'       && _selColor       != null && s('color')       != _selColor)       return false;
            if (skipKey != 'modelNumber' && _selModelNumber != null && s('modelNumber') != _selModelNumber) return false;
            
            if (_onlyVerified) {
              final hasImei = data['hasImei'] == true;
              if (!hasImei) return false;
            }
            return true;
          }

          List<String> getAvailable(String key) {
            return rawDocs
                .where((d) => matches(d, skipKey: key))
                .map((d) => (key == 'condition'
                    ? d.data()[key]
                    : d.data()['specs']?[key])?.toString().trim() ?? '')
                .where((v) => v.isNotEmpty)
                .toSet()
                .toList()..sort();
          }

          final conditionVals   = getAvailable('condition');
          final storageVals     = getAvailable('storage');
          final ramVals         = getAvailable('ram');
          final versionVals     = getAvailable('version');
          final romVals         = getAvailable('rom');
          final colorVals       = getAvailable('color');
          final modelNumberVals = _isApple ? getAvailable('modelNumber') : <String>[];

          // ── Apply all filters for the final list ──────────────────────────
          var filtered = rawDocs.where((d) => matches(d)).toList();

          // ── Sort ──────────────────────────────────────────────────────────
          filtered.sort((a, b) {
            double priceA = double.tryParse(a.data()['price']?.toString() ?? '') ?? 0.0;
            double priceB = double.tryParse(b.data()['price']?.toString() ?? '') ?? 0.0;
            final ca = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final cb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return switch (_sortBy) {
              'price_desc' => priceB.compareTo(priceA),
              'newest'     => cb.compareTo(ca),
              _            => priceA.compareTo(priceB),
            };
          });

          // City-priority: buyer's city first
          if (_buyerCity.isNotEmpty) {
            filtered.sort((a, b) {
              final aC = (a.data()['sellerCity'] ?? '').toString().toLowerCase();
              final bC = (b.data()['sellerCity'] ?? '').toString().toLowerCase();
              final city = _buyerCity.toLowerCase();
              return (aC == city ? 0 : 1).compareTo(bC == city ? 0 : 1);
            });
          }

          // ── Header data ───────────────────────────────────────────────────
          final prices = filtered
              .map((d) => (double.tryParse(d.data()['price']?.toString() ?? '') ?? 0.0).toInt())
              .where((p) => p > 0)
              .toList();
          final lowestPrice = prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
          final headerImage = rawDocs.isNotEmpty
              ? (rawDocs.first.data()['image'] ?? '').toString()
              : '';

          return CustomScrollView(
            key: const PageStorageKey('model_listings_scroll'),
            controller: _scrollController,
            slivers: [

              // ── Header ───────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(
                  model:       widget.model,
                  brand:       widget.brand,
                  count:       rawDocs.length,
                  lowestPrice: lowestPrice,
                  imageUrl:    headerImage,
                  scheme:      scheme,
                  textTheme:   textTheme,
                ),
              ),

              // ── Filter bar ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _FilterBar(
                  isOpen:            _filtersOpen,
                  activeCount:       _activeFilterCount,
                  onToggle:          () => setState(() => _filtersOpen = !_filtersOpen),
                  onClear:           _clearFilters,
                  isApple:           _isApple,
                  // values
                  conditionVals:     conditionVals,
                  storageVals:       storageVals,
                  ramVals:           ramVals,
                  versionVals:       versionVals,
                  romVals:           romVals,
                  colorVals:         colorVals,
                  modelNumberVals:   modelNumberVals,
                  // selected
                  selCondition:      _selCondition,
                  selStorage:        _selStorage,
                  selRam:            _selRam,
                  selVersion:        _selVersion,
                  selRom:            _selRom,
                  selColor:          _selColor,
                  selModelNumber:    _selModelNumber,
                  sortBy:            _sortBy,
                  // callbacks
                  onCondition:       (v) => setState(() => _selCondition   = v),
                  onStorage:         (v) => setState(() => _selStorage     = v),
                  onRam:             (v) => setState(() => _selRam         = v),
                  onVersion:         (v) => setState(() => _selVersion     = v),
                  onRom:             (v) => setState(() => _selRom         = v),
                  onColor:           (v) => setState(() => _selColor       = v),
                  onModelNumber:     (v) => setState(() => _selModelNumber = v),
                  onSort:            (v) => setState(() => _sortBy         = v ?? 'price_asc'),
                  onlyVerified:      _onlyVerified,
                  onVerifiedChanged: (v) => setState(() => _onlyVerified  = v),
                  scheme:            scheme,
                  textTheme:         textTheme,
                ),
              ),

              // ── Result count ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'Showing ${filtered.length} of ${rawDocs.length} listings',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (_activeFilterCount > 0) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: _clearFilters,
                          child: Text(
                            'Clear Filters',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Empty state ───────────────────────────────────────────────
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No listings match your filters')),
                ),

              // ── Accordion list ────────────────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final doc  = filtered[i];
                    final data = doc.data();
                    final isExpanded = _expanded.contains(doc.id);

                    return _ListingRow(
                      rank:       i + 1,
                      doc:        doc,
                      data:       data,
                      isExpanded: isExpanded,
                      onTap:      () => setState(() {
                        if (isExpanded) {
                          _expanded.remove(doc.id);
                        } else {
                          _expanded.add(doc.id);
                        }
                      }),
                      onNavigate: () {
                        final p = Product.fromFirestore(doc.id, data);
                        context.push(
                          AppRoutes.productPath(doc.id),
                          extra: {
                            'product': p,
                            'sellerName': p.sellerName,
                          },
                        );
                      },
                      scheme:    scheme,
                      textTheme: textTheme,
                    );
                  },
                  childCount: filtered.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),

      // ── Floating Back Button ─────────────────────────────────────────────
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            color: scheme.onSurface,
          ),
        ),
      ),
    ],
  ),
);
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String model, brand, imageUrl;
  final int count;
  final int? lowestPrice;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _Header({
    required this.model,
    required this.brand,
    required this.count,
    required this.lowestPrice,
    required this.imageUrl,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Spacer for floating back button
        SizedBox(height: MediaQuery.of(context).padding.top + 60),

        // Model name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            model,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),

        // Count + lowest price row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$count ${count == 1 ? 'listing' : 'listings'}",
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (lowestPrice != null) Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Starting at',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    '${_fmt(lowestPrice!)} MMK',
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Model image
        if (imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              height: 180,
              child: AppNetworkImage(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          )
        else
          const SizedBox(height: 12),
      ],
    );
  }

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─── Filter Bar ────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool isOpen, isApple;
  final int activeCount;
  final VoidCallback onToggle, onClear;
  final List<String> conditionVals, storageVals, ramVals, versionVals,
      romVals, colorVals, modelNumberVals;
  final String? selCondition, selStorage, selRam, selVersion, selRom,
      selColor, selModelNumber;
  final String sortBy;
  final ValueChanged<String?> onCondition, onStorage, onRam, onVersion,
      onRom, onColor, onModelNumber, onSort;
  final bool onlyVerified;
  final ValueChanged<bool> onVerifiedChanged;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _FilterBar({
    required this.isOpen,
    required this.isApple,
    required this.activeCount,
    required this.onToggle,
    required this.onClear,
    required this.conditionVals,
    required this.storageVals,
    required this.ramVals,
    required this.versionVals,
    required this.romVals,
    required this.colorVals,
    required this.modelNumberVals,
    required this.selCondition,
    required this.selStorage,
    required this.selRam,
    required this.selVersion,
    required this.selRom,
    required this.selColor,
    required this.selModelNumber,
    required this.sortBy,
    required this.onCondition,
    required this.onStorage,
    required this.onRam,
    required this.onVersion,
    required this.onRom,
    required this.onColor,
    required this.onModelNumber,
    required this.onSort,
    required this.onlyVerified,
    required this.onVerifiedChanged,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          // ── Toggle row ─────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: scheme.onSurface),
                  const SizedBox(width: 8),
                  Text('Filters', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded filter panel ──────────────────────────────────────
          if (isOpen) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (conditionVals.isNotEmpty)
                    _dropRow('Condition', selCondition, conditionVals, onCondition, scheme, textTheme),
                  if (storageVals.isNotEmpty)
                    _dropRow('Storage', selStorage, storageVals, onStorage, scheme, textTheme),
                  if (!isApple && ramVals.isNotEmpty)
                    _dropRow('RAM', selRam, ramVals, onRam, scheme, textTheme),
                  if (colorVals.isNotEmpty)
                    _dropRow('Color', selColor, colorVals, onColor, scheme, textTheme),
                  if (versionVals.isNotEmpty)
                    _dropRow('Version', selVersion, versionVals, onVersion, scheme, textTheme),
                  if (romVals.isNotEmpty)
                    _dropRow('ROM', selRom, romVals, onRom, scheme, textTheme),
                  if (isApple && modelNumberVals.isNotEmpty)
                    _dropRow('Model Number', selModelNumber, modelNumberVals, onModelNumber, scheme, textTheme),
                  _dropRow('Sort By', sortBy == 'price_asc' ? null : sortBy, [
                    'price_asc', 'price_desc', 'newest',
                  ], onSort, scheme, textTheme,
                  labelMap: const {
                    'price_asc':  'Price: Low → High',
                    'price_desc': 'Price: High → Low',
                    'newest':     'Newest First',
                  }),

                  // ── IMEI & Device Verification filter ──────────────────
                  const SizedBox(height: 4),
                  Divider(height: 1, color: scheme.outlineVariant),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => onVerifiedChanged(!onlyVerified),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: onlyVerified
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: onlyVerified ? AppColors.success : AppColors.error,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: onlyVerified ? AppColors.success : Colors.transparent,
                              border: Border.all(
                                color: onlyVerified ? AppColors.success : AppColors.error,
                                width: 2,
                              ),
                            ),
                            child: onlyVerified
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('IMEI ပါသော ဖုန်းများသာ ပြမည်',
                                    style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: onlyVerified ? AppColors.success : AppColors.error)),
                                Text('IMEI နံပါတ် မပါသော listing များ ဖျောက်မည်',
                                    style: textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (activeCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: onClear,
                        child: Text(
                          'Clear Filters',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _dropRow(
  String label,
  String? selected,
  List<String> values,
  ValueChanged<String?> onChanged,
  ColorScheme scheme,
  TextTheme textTheme, {
  Map<String, String>? labelMap,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        DropdownMenuItem<String>(value: null, child: Text('All $label')),
        ...values.map((v) => DropdownMenuItem<String>(
          value: v,
          child: Text(labelMap?[v] ?? v),
        )),
      ],
      onChanged: onChanged,
    ),
  );
}

// ─── Listing Row (accordion) ───────────────────────────────────────────────

class _ListingRow extends StatelessWidget {
  final int rank;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic> data;
  final bool isExpanded;
  final VoidCallback onTap, onNavigate;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _ListingRow({
    required this.rank,
    required this.doc,
    required this.data,
    required this.isExpanded,
    required this.onTap,
    required this.onNavigate,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final price      = (data['price'] ?? '').toString();
    final imageUrl   = (data['image'] ?? '').toString();
    final sellerId   = (data['sellerId'] ?? '').toString();
    final specs      = data['specs'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        // ── Collapsed row ───────────────────────────────────────────────
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rank badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank == 1 ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: rank == 1 ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Listing ID + Seller mini-profile
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Listing ID + copy button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#${doc.id.substring(0, 8).toUpperCase()}',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              letterSpacing: 0.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: doc.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Listing ID copied'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Seller mini-profile
                      _SellerRowInline(
                        sellerId: sellerId,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),

                // Price + expand
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(double.tryParse(price) ?? 0).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MMK',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: scheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Expanded detail ─────────────────────────────────────────────
        if (isExpanded)
          Container(
            color: scheme.surfaceContainerLowest,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Photo + Specs side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image with Hero animation
                    if (imageUrl.isNotEmpty)
                      Hero(
                        tag: 'product-${doc.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppNetworkImage(
                            imageUrl,
                            width: 90,
                            height: 110,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),

                    // Spec list — vertical
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (specs['warrantyDays'] != null)
                            _specRow(_warranty(specs['warrantyDays']), scheme, textTheme),
                          if (specs['batteryPercent'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(text: '🔋 '),
                                    TextSpan(
                                      text: '${specs['batteryPercent']}%',
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (specs['cycleCount'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(text: '🔄 '),
                                    TextSpan(
                                      text: 'Cycle: ${specs['cycleCount']}',
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if ((data['icloudStatus'] ?? '').toString().isNotEmpty)
                            _specRow(
                              data['icloudStatus'] == 'locked' ? '🔒 iCloud Locked' : '✅ iCloud Clean',
                              scheme, textTheme,
                              isWarning: data['icloudStatus'] == 'locked',
                            ),
                          if ((data['carrierLock'] ?? '').toString().isNotEmpty)
                            _specRow(
                              data['carrierLock'] == 'locked' ? '🔒 Carrier Locked' : 'Unlocked',
                              scheme, textTheme,
                              isWarning: data['carrierLock'] == 'locked',
                            ),
                          if ((data['imeiStatus'] ?? '') == 'valid')
                            _specRow('✅ IMEI Verified', scheme, textTheme, isGood: true),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Accessories ──────────────────────────────────────────
                if (data['accessories'] is Map && (data['accessories'] as Map).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (data['accessories']['box'] == true)      _accChip('Box'),
                      if (data['accessories']['charger'] == true)   _accChip('Charger'),
                      if (data['accessories']['cable'] == true)     _accChip('Cable'),
                      if (data['accessories']['earphones'] == true) _accChip('Earphones'),
                      if (data['accessories']['receipt'] == true)   _accChip('Receipt'),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // View more details — bottom right
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onNavigate,
                    child: Text(
                      'View more details →',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }

  Widget _accChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 10, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _warranty(dynamic days) {
    final d = int.tryParse(days.toString()) ?? 0;
    if (d == 0)   return 'No warranty';
    if (d == 365) return '1-Year Warranty';
    if (d == 730) return '2-Year Warranty';
    if (d >= 30)  return '${d ~/ 30}-Month Warranty';
    return '$d-Day Warranty';
  }

  Widget _specRow(
    String label,
    ColorScheme scheme,
    TextTheme textTheme, {
    bool isWarning = false,
    bool isGood = false,
  }) {
    final Color color = isWarning
        ? scheme.error
        : isGood
            ? AppColors.success
            : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Seller inline (collapsed row) ────────────────────────────────────────

// ✅ Global cache to prevent flickering across list rebuilds
final Map<String, Map<String, dynamic>> _sellerCache = {};

class _SellerRowInline extends StatelessWidget {
  final String sellerId;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _SellerRowInline({
    required this.sellerId,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (sellerId.isEmpty) return const SizedBox.shrink();

    // ── 1) Use cached data immediately if available ──────────────────────
    if (_sellerCache.containsKey(sellerId)) {
      return _buildContent(_sellerCache[sellerId]!);
    }

    // ── 2) Listen for live updates and fill cache ────────────────────────
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(sellerId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          // No spinner here to prevent "flapping" in the list
          return const SizedBox(width: 20, height: 20);
        }

        final u = snap.data!.data() ?? {};
        _sellerCache[sellerId] = u; // Cache it for future rebuilds

        return _buildContent(u);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> u) {
    final name       = (u['name'] ?? 'User').toString();
    final profileUrl = (u['profileImage'] ?? '').toString();
    final isVerified = u['isVerified'] == true;
    final sales      = (u['totalSales'] ?? u['completedSales'] ?? 0);
    final salesInt   = sales is int ? sales : int.tryParse(sales.toString()) ?? 0;

    final isOnline = () {
      if (u['isOnline'] != true) return false;
      final ls = u['lastSeen'];
      if (ls == null || ls is! Timestamp) return true;
      return DateTime.now().difference(ls.toDate()).inMinutes < 10;
    }();

    return Row(
      children: [
        // Avatar
        Stack(
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: scheme.surfaceContainerHighest,
              backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
              child: profileUrl.isEmpty
                  ? Icon(Icons.person, size: 10, color: scheme.onSurfaceVariant)
                  : null,
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 1),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 5),
        // Name + verified
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 3),
                const Icon(Icons.verified, color: Color(0xFF1DA1F2), size: 11),
              ],
            ],
          ),
        ),
        if (salesInt > 0) ...[
          const SizedBox(width: 6),
          Text(
            '• $salesInt Sales',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
