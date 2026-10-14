import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import '../../../core/utils/require_login.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../core/providers/admin_providers.dart';
import '../widgets/brand_wall_view.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';
  double? _minPrice;
  double? _maxPrice;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _enterSearch() => setState(() => _isSearching = true);

  void _exitSearch() {
    _searchCtrl.clear();
    setState(() {
      _q = '';
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    // ── Admin Badge Counts ───────────────────────────────────────────────────
    final pendingOrders = ref.watch(pendingOrdersProvider).value ?? 0;
    final adminOrderNotifs = ref.watch(adminOrderNotifsProvider).value ?? 0;
    final modelRequests = ref.watch(modelRequestsProvider).value ?? 0;
    final imeiPending = ref.watch(imeiPendingProvider).value ?? 0;
    final verifyRequests = ref.watch(verifyRequestsProvider).value ?? 0;
    final reportNotifs = ref.watch(reportNotifsProvider).value ?? 0;
    final buyerUnread = ref.watch(buyerUnreadProvider).value ?? 0;
    final sellerUnread = ref.watch(sellerUnreadProvider).value ?? 0;

    final scheme = Theme.of(context).colorScheme;
    final sw = MediaQuery.of(context).size.width;
    final titleSize = sw < 360 ? 22.0 : sw < 400 ? 24.0 : sw < 600 ? 26.0 : 30.0;
    final iconSz    = sw < 360 ? 18.0 : 20.0;
    final iconMinW  = sw < 360 ? 24.0 : sw < 600 ? 28.0 : 32.0;
    const iconHPad  = 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(
        titleSpacing: 0,
        leadingWidth: _isSearching ? null : 0,
        leading: _isSearching
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _exitSearch,
        )
            : const SizedBox.shrink(),
        titleWidget: _isSearching
            ? _searchField(context)
            : Padding(
          padding: const EdgeInsets.only(left: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Sigma Moby',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: titleSize,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        actions: _isSearching
            ? null
            : _buildActionItems(
                context, 
                user, 
                isAdmin,
                pendingOrders,
                adminOrderNotifs,
                modelRequests,
                imeiPending,
                verifyRequests,
                reportNotifs,
                buyerUnread,
                sellerUnread,
                scheme, 
                iconSz, 
                iconMinW, 
                iconHPad, 
                sw,
              ),
      ),

      body: MaxWidthBox(
        child: BrandWallView(
          searchQuery: _q,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
        ),
      ),
    );
  }

  void _showPriceFilterSheet() {
    final scheme = Theme.of(context).colorScheme;
    final minCtrl = TextEditingController(text: _minPrice?.toInt().toString() ?? '');
    final maxCtrl = TextEditingController(text: _maxPrice?.toInt().toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'စျေးနှုန်းဖြင့် ရှာဖွေရန်',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _minPrice = null;
                      _maxPrice = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'အနည်းဆုံး (Min)',
                      prefixText: 'Ks ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'အများဆုံး (Max)',
                      prefixText: 'Ks ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    _minPrice = double.tryParse(minCtrl.text.replaceAll(',', ''));
                    _maxPrice = double.tryParse(maxCtrl.text.replaceAll(',', ''));
                  });
                  Navigator.pop(context);
                },
                child: const Text('Filter လုပ်မည်', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            // Quick ranges
            const Text('အမြန်ရွေးရန်', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _quickRangeChip('၅ သိန်းအောက်', null, 500000),
                _quickRangeChip('၅ သိန်း - ၁၀ သိန်း', 500000, 1000000),
                _quickRangeChip('၁၀ သိန်း - ၂၀ သိန်း', 1000000, 2000000),
                _quickRangeChip('၂၀ သိန်းအထက်', 2000000, null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickRangeChip(String label, double? min, double? max) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        setState(() {
          _minPrice = min;
          _maxPrice = max;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search...',
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () {
            _searchCtrl.clear();
            setState(() => _q = '');
          },
        ),
      ),
      onChanged: (v) => setState(() => _q = v),
    );
  }

  List<Widget> _buildActionItems(
      BuildContext context,
      User? user,
      bool isAdmin,
      int pendingOrders,
      int adminOrderNotifs,
      int modelRequests,
      int imeiPending,
      int verifyRequests,
      int reportNotifs,
      int buyerUnread,
      int sellerUnread,
      ColorScheme scheme,
      double iconSz,
      double iconMinW,
      double iconHPad,
      double sw,
      ) {
    final isLoggedIn = user != null;
    final adminBadgeTotal = isAdmin
        ? (buyerUnread + pendingOrders + modelRequests + verifyRequests + imeiPending)
        : 0;
    return [
      IconButton(
        icon: Stack(
          children: [
            const Icon(Icons.tune),
            if (_minPrice != null || _maxPrice != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        onPressed: _showPriceFilterSheet,
        constraints: BoxConstraints(minWidth: iconMinW, minHeight: iconMinW),
        padding: EdgeInsets.symmetric(horizontal: iconHPad, vertical: 4),
      ),
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: _enterSearch,
        constraints: BoxConstraints(minWidth: iconMinW, minHeight: iconMinW),
        padding: EdgeInsets.symmetric(horizontal: iconHPad, vertical: 4),
      ),

      if (!_isSearching && isLoggedIn && isAdmin)
        Theme(
          data: Theme.of(context).copyWith(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Stack(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Admin',
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: iconHPad + 4, vertical: 8),
                  child: Icon(Icons.admin_panel_settings_outlined,
                      size: iconSz, color: Colors.white),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'dashboard':
                      context.push(AppRoutes.adminDashboard);
                      break;
                    case 'brands':
                      context.push(AppRoutes.manageBrands);
                      break;
                    case 'models':
                      context.push(AppRoutes.manageModels);
                      break;
                    case 'orders':
                      context.push(AppRoutes.adminOrders);
                      break;
                    case 'shipping':
                      context.push(AppRoutes.adminShippingSettings);
                      break;
                    case 'feeSettings':
                      context.push(AppRoutes.adminFeeSettings);
                      break;
                    case 'pendingFees':
                      context.push(AppRoutes.adminPendingFees);
                      break;
                    case 'imeiReports':
                      context.push(AppRoutes.adminImeiReports);
                      break;
                    case 'imeiVerification':
                      context.push(AppRoutes.adminImeiVerification);
                      break;
                    case 'modelRequests':
                      context.push(AppRoutes.adminModelRequests);
                      break;
                    case 'userReports':
                      context.push(AppRoutes.adminUserReports);
                      break;
                    case 'bannedUsers':
                      context.push(AppRoutes.adminBannedUsers);
                      break;
                    case 'verifySellers':
                      context.push(AppRoutes.adminVerifySellers);
                      break;
                    case 'announce':
                      context.push(AppRoutes.adminAnnounce);
                      break;
                    case 'paymentSettings':
                      context.push(AppRoutes.adminPaymentSettings);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'dashboard',
                    child: Row(
                      children: [
                        const Icon(Icons.dashboard_outlined, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Dashboard (KPIs)')),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'orders',
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Admin Orders')),
                        if (pendingOrders + adminOrderNotifs > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              (pendingOrders + adminOrderNotifs) > 9
                                  ? '9+'
                                  : '${pendingOrders + adminOrderNotifs}',
                              style: TextStyle(
                                color: scheme.onError,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'brands',
                    child: ListTile(
                      leading: Icon(Icons.format_list_numbered),
                      title: Text('Manage Brands'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'models',
                    child: ListTile(
                      leading: Icon(Icons.settings_suggest_outlined),
                      title: Text('Manage Models'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'shipping',
                    child: ListTile(
                      leading: Icon(Icons.local_shipping_outlined),
                      title: Text('Shipping Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'feeSettings',
                    child: ListTile(
                      leading: Icon(Icons.percent_outlined),
                      title: Text('Fee Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pendingFees',
                    child: ListTile(
                      leading: Icon(Icons.account_balance_wallet_outlined),
                      title: Text('Pending Fees'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'imeiVerification',
                    child: ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: const Text('IMEI Verification'),
                      contentPadding: EdgeInsets.zero,
                      trailing: imeiPending > 0
                          ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          imeiPending > 9
                              ? '9+'
                              : '$imeiPending',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                          : null,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'imeiReports',
                    child: ListTile(
                      leading: Icon(Icons.security_outlined),
                      title: Text('IMEI Reports'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'modelRequests',
                    child: ListTile(
                      leading: const Icon(Icons.phone_android_outlined),
                      title: const Text('Model Requests'),
                      contentPadding: EdgeInsets.zero,
                      trailing: modelRequests > 0
                          ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          modelRequests > 9
                              ? '9+'
                              : '$modelRequests',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                          : null,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'userReports',
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('User Reports'),
                      contentPadding: EdgeInsets.zero,
                      trailing: reportNotifs > 0
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          reportNotifs > 9 ? '9+' : '$reportNotifs',
                          style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 11),
                        ),
                      )
                          : null,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'bannedUsers',
                    child: ListTile(
                      leading: Icon(Icons.block_outlined),
                      title: Text('Banned Users'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'verifySellers',
                    child: ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: const Text('Verify Sellers'),
                      contentPadding: EdgeInsets.zero,
                      trailing: verifyRequests > 0
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          verifyRequests > 9 ? '9+' : '$verifyRequests',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                          : null,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'announce',
                    child: ListTile(
                      leading: Icon(Icons.campaign_outlined),
                      title: Text('Announce'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'paymentSettings',
                    child: ListTile(
                      leading: Icon(Icons.credit_card_outlined),
                      title: Text('Payment Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              if (adminBadgeTotal > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                    const BoxConstraints(minWidth: 17, minHeight: 17),
                    child: Text(
                      adminBadgeTotal > 9 ? '9+' : '$adminBadgeTotal',
                      style: TextStyle(
                        color: scheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),

      if (!_isSearching) ...[
        IconButton(
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () => requireLogin(
            context,
            message: 'Product တင်ရန် login လိုအပ်သည်',
            onAuthorized: () => context.push(AppRoutes.addProduct),
          ),
          constraints: BoxConstraints(minWidth: iconMinW, minHeight: iconMinW),
          padding: EdgeInsets.symmetric(horizontal: iconHPad, vertical: 4),
        ),

        if (!isLoggedIn)
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () => requireLogin(
              context,
              message: 'Chat ကြည့်ရန် login လိုအပ်သည်',
              onAuthorized: () {},
            ),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(4),
          )
        else
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int totalUnread = 0;
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedFor =
                      data['deletedFor'] as Map<String, dynamic>? ?? {};
                  if (deletedFor[user.uid] == true) continue;
                  final unreadCount =
                      data['unreadCount'] as Map<String, dynamic>? ?? {};
                  final chatUnread =
                      (unreadCount[user.uid] as num?)?.toInt() ?? 0;
                  if (chatUnread > 0) totalUnread += 1;
                }
              }
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined),
                    onPressed: () => context.push(AppRoutes.chats),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(4),
                  ),
                  if (totalUnread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          totalUnread > 9 ? '9+' : '$totalUnread',
                          style: TextStyle(
                            color: scheme.onError,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        _AppBarBadge(
          icon: Icons.shopping_bag_outlined,
          count: isAdmin ? 0 : buyerUnread,
          scheme: scheme,
          iconSz: iconSz,
          iconMinW: iconMinW,
          iconHPad: iconHPad,
          onTap: () => requireLogin(
            context,
            message: 'Orders ကြည့်ရန် login လိုအပ်သည်',
            onAuthorized: () => context.push(AppRoutes.buyerOrders),
          ),
        ),

        _AppBarBadge(
          icon: Icons.storefront_outlined,
          count: isAdmin ? 0 : sellerUnread,
          scheme: scheme,
          iconSz: iconSz,
          iconMinW: iconMinW,
          iconHPad: iconHPad,
          onTap: () => requireLogin(
            context,
            message: 'Orders ကြည့်ရန် login လိုအပ်သည်',
            onAuthorized: () => context.push(AppRoutes.sellerOrders),
          ),
        ),
      ],
    ];
  }
}

class _AppBarBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final double iconSz;
  final double iconMinW;
  final double iconHPad;

  const _AppBarBadge({
    required this.icon,
    required this.count,
    required this.scheme,
    required this.onTap,
    this.iconSz   = 22,
    this.iconMinW = 32,
    this.iconHPad = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon, size: iconSz),
          onPressed: onTap,
          constraints: BoxConstraints(minWidth: iconMinW, minHeight: iconMinW),
          padding: EdgeInsets.symmetric(horizontal: iconHPad, vertical: 4),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(
                  color: scheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
