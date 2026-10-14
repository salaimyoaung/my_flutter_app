import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/device_types.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/brand_app_bar.dart';
import '../../../data/models/add_product_form_data.dart';
import '../../../data/services/model_service.dart';
import '../../../data/services/product_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../shared/widgets/brand_model_section.dart';
import '../../../shared/widgets/product_image_picker.dart';
import '../../../shared/widgets/specs_section.dart';
import '../controllers/add_product_controller.dart';
import '../../../core/services/fee_service.dart';
import '../widgets/add_product/accessories_section.dart';
import '../widgets/add_product/contact_price_section.dart';
import '../widgets/add_product/details_section.dart';
import '../widgets/add_product/device_type_condition_section.dart';
import '../widgets/add_product/imei_section.dart';
import '../widgets/add_product/submit_section.dart';
import '../widgets/model_request_dialog.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

// ─── Seller Deposit Info Card ─────────────────────────────────────────────────
// Explains how the deposit system protects sellers from double delivery costs.
// Collapsible so experienced sellers can hide it after reading once.

class _SellerDepositInfoCard extends StatefulWidget {
  @override
  State<_SellerDepositInfoCard> createState() => _SellerDepositInfoCardState();
}

class _SellerDepositInfoCardState extends State<_SellerDepositInfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          // ── Header (always visible) ──────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seller ကို ဘယ်လို ကာကွယ်ပေးသလဲ?',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Body (expandable) ────────────────────────────────────────────
          if (_expanded) ...[
            Divider(
                height: 1,
                color: scheme.primary.withValues(alpha: 0.2)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _point(
                    context,
                    icon: Icons.lock_outline,
                    text:
                        'Buyer က order တင်တိုင်း Deposit ကြိုပေးရသည်။',
                  ),
                  const SizedBox(height: 8),
                  _point(
                    context,
                    icon: Icons.local_shipping_outlined,
                    text:
                        'Depositသည် deliveryခ ဖြစ်သောကြောင့် '
                        'Seller က deliveryခ ကြိုပေးရန် မလိုပါ။',
                  ),
                  const SizedBox(height: 8),
                  _point(
                    context,
                    icon: Icons.replay_outlined,
                    text:
                        'Buyerက product မယူတော့ပဲ ပြန်ပို့ပါက '
                        'Seller ကုန်ကျမည့် deliveryခ နှစ်ခုစာကို '
                        'deposit ထဲကနေ sellerဆီ ပြန်လွှဲပေးပါမည်'
                    ,
                  ),
                  const SizedBox(height: 8),
                  _point(
                    context,
                    icon: Icons.check_circle_outline,
                    text:
                        'Buyerနဲ့ Sellerကိုယ်တိုင် နှစ်ဖက်လုံးမှ confirm မလုပ်မချင်း '
                        'Deposit ကို Admin မထုတ်ပေးပါ — '
                        'ထို့ကြောင့် Seller လိမ်ညာခံရမည်ကို စိုးရိမ်စရာ မလိုပါ',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _point(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onPrimaryContainer,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddProductPageState extends State<AddProductPage> {
  // ─── Accessories ───────────────────────────────────────────────────────────
  bool accBox = false;
  bool accCharger = false;
  bool accCable = false;
  bool accEarphones = false;
  bool accReceipt = false;

  // ─── Services ──────────────────────────────────────────────────────────────
  final ModelService _modelService = ModelService();
  final ProductService _productService = ProductService();
  final StorageService _storageService = StorageService();

  late final AddProductController _controller = AddProductController(
    productService: _productService,
    storageService: _storageService,
    firestore: FirebaseFirestore.instance,
  );

  // ─── Streams ───────────────────────────────────────────────────────────────
  Stream<List<String>>? _brandsStream;
  Stream<List<PhoneModelEntry>>? _modelsStream;

  // ─── Text controllers ──────────────────────────────────────────────────────
  final TextEditingController priceController = TextEditingController();
  final TextEditingController originalPriceController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController imeiController = TextEditingController();
  XFile? _imeiPhoto;
  final TextEditingController detailController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController seriesController = TextEditingController();

  // ─── Device type constants ─────────────────────────────────────────────────
  // Using DeviceTypes constants from lib/core/constants/device_types.dart

  static const List<String> conditions = [
    "Original Brand New (Sealed)",
    "Open Box (Original)",
    "Like New (Original)",
    "Used (Good) (Original)",
    "Used (Fair) (Original)",
    "China Refurbished(တရုတ်လိုင်း)",
  ];

  // ─── Form state ────────────────────────────────────────────────────────────
  String selectedDeviceType = DeviceTypes.androidPhone;
  String selectedCondition = "Original Brand New (Sealed)";
  int? selectedRam;
  int? selectedStorage;
  String selectedColor = "";
  int? selectedBatteryPercent;
  int? selectedCycleCount;
  int? selectedWarrantyDays;
  String? selectedVersion;
  String? selectedRom;
  String modelNumber = "";
  String selectedIcloudStatus = 'clean';
  String selectedCarrierLock = 'unlocked';
  String? selectedSimType;
  bool batteryUnverifiable = false;

  bool _isUploading = false;

  // ── Fee tiers (loaded once from Firestore) ─────────────────────────────────
  Map<String, int> _feeTiers = const {
    'tier1Max': 500000,
    'tier1Fee': 5000,
    'tier2Max': 5000000,
    'tier2Fee': 10000,
    'tier3Fee': 15000,
  };

  List<XFile> _pickedImages = [];
  List<dynamic> _selectedAssets = []; // Store AssetEntity from wechat_assets_picker

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _brandsStream = _modelService.streamBrandsByDevice(selectedDeviceType);
    _modelsStream = _modelService.streamPhoneModelsByDevice(selectedDeviceType);
    _loadFeeTiers();
  }

  Future<void> _loadFeeTiers() async {
    final tiers = await FeeService.loadTiers();
    if (mounted) setState(() => _feeTiers = tiers);
  }

  @override
  void dispose() {
    priceController.dispose();
    originalPriceController.dispose();
    phoneController.dispose();
    imeiController.dispose();
    detailController.dispose();
    brandController.dispose();
    modelController.dispose();
    seriesController.dispose();
    super.dispose();
  }

  // ─── Stream helpers ────────────────────────────────────────────────────────

  void _refreshBrandsStream() {
    setState(() {
      _brandsStream = _modelService.streamBrandsByDevice(selectedDeviceType);
      _modelsStream = _modelService.streamPhoneModelsByDevice(selectedDeviceType);
    });
  }

  // ─── Business logic ────────────────────────────────────────────────────────

  int? _autoRamFor(String dt, String brand, String model) {
    final b = brand.toLowerCase().trim();
    final m = model.toLowerCase().trim();
    if (dt == DeviceTypes.iphone || dt == DeviceTypes.ipad || b == "apple") {
      if (m.contains("iphone 11")) return 4;
      if (m.contains("iphone 12")) return 4;
      if (m.contains("iphone 13")) return 4;
      if (m.contains("iphone 14")) return 6;
      if (m.contains("iphone 15")) return 6;
      if (m.contains("iphone 16")) return 8;
    }
    return null;
  }

  void _maybeAutoFillRam() {
    if (selectedRam != null) return;
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    if (brand.isEmpty || model.isEmpty) return;
    final r = _autoRamFor(selectedDeviceType, brand, model);
    if (r != null) setState(() => selectedRam = r);
  }

  void _onDeviceTypeChanged(String? v) {
    if (v == null) return;
    setState(() {
      selectedDeviceType = v;
      brandController.clear();
      seriesController.clear();
      modelController.clear();
    });
    _refreshBrandsStream();
  }

  AddProductFormData _buildFormData() {
    return AddProductFormData(
      version: selectedVersion,
      rom: selectedRom,
      modelNumber: modelNumber,
      icloudStatus: selectedIcloudStatus,
      carrierLock: selectedCarrierLock,
      simType: selectedSimType,
      batteryUnverifiable: batteryUnverifiable,
      deviceType: selectedDeviceType,
      condition: selectedCondition,
      price: priceController.text,
      originalPrice: originalPriceController.text,
      phone: phoneController.text,
      imei: imeiController.text,
      detail: detailController.text,
      brand: brandController.text,
      series: seriesController.text,
      model: modelController.text,
      ram: selectedRam,
      storage: selectedStorage,
      color: selectedColor,
      batteryPercent: selectedBatteryPercent,
      cycleCount: selectedCycleCount,
      warrantyDays: selectedWarrantyDays,
      images: _pickedImages,
      imeiPhoto: _imeiPhoto,
      accBox: accBox,
      accCharger: accCharger,
      accCable: accCable,
      accEarphones: accEarphones,
      accReceipt: accReceipt,
    );
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isUploading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack("အရင်ဆုံး Login ဝင်ပါ");
      return;
    }

    final formData = _buildFormData();

    // ─── Controller validation (Centralized) ─────────────────────────────────
    final validationError = _controller.validate(formData);
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    setState(() => _isUploading = true);

    try {
      // ─── Strict Brand/Model Check ──────────────────────────────────────────
      final brands = await _modelService.streamBrandsByDevice(selectedDeviceType).first;
      final entries = await _modelService.streamPhoneModelsByDevice(selectedDeviceType).first;

      final bInput = brandController.text.trim().toLowerCase();
      final sInput = seriesController.text.trim().toLowerCase();
      final mInput = modelController.text.trim().toLowerCase();

      final brandExists = brands.any((b) => b.toLowerCase() == bInput);
      final modelExists = entries.any((e) {
        final eBrand = e.brand.trim().toLowerCase();
        final eSeries = (e.series?.trim().isEmpty ?? true) ? 'other' : e.series!.trim().toLowerCase();
        final eModel = e.model.trim().toLowerCase();

        // Series input might be empty or 'other' if user didn't pick one
        final effectiveSInput = sInput.isEmpty ? 'other' : sInput;

        return eBrand == bInput && eSeries == effectiveSInput && eModel == mInput;
      });

      if (!brandExists || !modelExists) {
        _showSnack("Brand/Model list ထဲတွင် မရှိပါ။ Model Request တင်ပေးပါ");
        setState(() => _isUploading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final sellerName =
      (userDoc.data()?['name'] ?? "အမည်မသိရောင်းသူ").toString();

      final submitError = await _controller.submit(
        sellerId: user.uid,
        sellerName: sellerName,
        data: formData,
      );

      if (!mounted) return;

      if (submitError != null) {
        _showSnack(submitError);
        return;
      }

      _showSnack("ပစ္စည်းတင်ပြီးပါပြီ");
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack("Upload Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── UI helpers ────────────────────────────────────────────────────────────

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String extractSeries(String model) {
    final m = model.trim();
    if (m.isEmpty) return "";
    final lower = m.toLowerCase();
    if (lower.startsWith('galaxy ')) {
      final parts = m.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final token = parts[1];
        final letter = token.isNotEmpty ? token[0].toUpperCase() : '';
        if (['S', 'A', 'Z', 'M'].contains(letter)) return letter;
      }
    }
    if (lower.startsWith('iphone')) return 'iPhone';
    return "";
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: "ပစ္စည်းအသစ်တင်ရန်"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // ── Seller protection info ─────────────────────────────────────
            _SellerDepositInfoCard(),

            const SizedBox(height: 12),

            BrandModelStatus(
              brandsStream: _brandsStream!,
              modelsStream: _modelsStream!,
            ),
            ProductImagePicker(
              images: _pickedImages,
              onChanged: (images) => setState(() => _pickedImages = images),
              isUploading: _isUploading,
              selectedAssets: List<AssetEntity>.from(_selectedAssets),
              onAssetsChanged: (assets) => setState(() => _selectedAssets = assets),
            ),
            DeviceTypeConditionSection(
              selectedDeviceType: selectedDeviceType,
              selectedCondition: selectedCondition,
              conditions: conditions,
              onDeviceTypeChanged: _onDeviceTypeChanged,
              onConditionChanged: (v) {
                if (v == null) return;
                setState(() => selectedCondition = v);
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.help_outline),
                label: const Text("Model မတွေ့ဘူးလား? Request တင်မယ်"),
                onPressed: brandController.text.trim().isEmpty
                    ? null
                    : () {
                  showDialog(
                    context: context,
                    builder: (_) => ModelRequestDialog(
                      brand: brandController.text.trim(),
                      deviceType: selectedDeviceType,
                      series: seriesController.text.trim(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            BrandModelSection(
              brandsStream: _brandsStream!,
              modelsStream: _modelsStream!,
              brandController: brandController,
              seriesController: seriesController,
              modelController: modelController,
              selectedDeviceType: selectedDeviceType,
              onBrandChanged: () {
                seriesController.clear();
                modelController.clear();
                setState(() {});
              },
              onSeriesChanged: () {
                modelController.clear();
                setState(() {});
              },
              onModelChanged: () {
                if (seriesController.text.isEmpty) {
                  seriesController.text = extractSeries(modelController.text);
                }
                setState(() {});
              },
              onModelInputChanged: () {
                if (seriesController.text.isEmpty) {
                  seriesController.text = extractSeries(modelController.text);
                }
                _maybeAutoFillRam();
                setState(() {});
              },
            ),
            const SizedBox(height: 6),
            ImeiSection(
              imeiController: imeiController,
              onImeiPhotoPicked: (p) => setState(() => _imeiPhoto = p),
              initialPhoto: _imeiPhoto,
            ),
            SpecsSection(
              selectedRam: selectedRam,
              selectedStorage: selectedStorage,
              selectedColor: selectedColor,
              selectedBatteryPercent: selectedBatteryPercent,
              selectedCycleCount: selectedCycleCount,
              selectedWarrantyDays: selectedWarrantyDays,
              deviceType: selectedDeviceType,
              condition: selectedCondition,
              selectedVersion: selectedVersion,
              selectedRom: selectedRom,
              modelNumber: modelNumber,
              onVersionChanged: (v) => setState(() => selectedVersion = v),
              onRomChanged: (v) => setState(() => selectedRom = v),
              onModelNumberChanged: (v) => setState(() => modelNumber = v),
              onRamChanged: (v) => setState(() => selectedRam = v),
              onStorageChanged: (v) => setState(() => selectedStorage = v),
              onColorChanged: (v) => setState(() => selectedColor = v ?? ""),
              onBatteryChanged: (v) =>
                  setState(() => selectedBatteryPercent = v),
              onCycleCountChanged: (v) =>
                  setState(() => selectedCycleCount = v),
              onWarrantyChanged: (v) =>
                  setState(() => selectedWarrantyDays = v),
              selectedIcloudStatus: selectedIcloudStatus,
              selectedCarrierLock: selectedCarrierLock,
              onIcloudStatusChanged: (v) =>
                  setState(() => selectedIcloudStatus = v),
              onCarrierLockChanged: (v) =>
                  setState(() => selectedCarrierLock = v),
              selectedSimType: selectedSimType,
              onSimTypeChanged: (v) => setState(() => selectedSimType = v),
              batteryUnverifiable: batteryUnverifiable,
              onBatteryUnverifiableChanged: (v) =>
                  setState(() => batteryUnverifiable = v),
            ),
            ContactPriceSection(
              priceController: priceController,
              originalPriceController: originalPriceController,
              phoneController: phoneController,
            ),

            // ── Platform fee live preview ──────────────────────────────────
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: priceController,
              builder: (context, value, _) {
                final price = double.tryParse(
                  value.text.trim().replaceAll(',', ''),
                );
                if (price == null || price <= 0) return const SizedBox.shrink();

                final fee = FeeService.calculateFee(
                  price,
                  tier1Max: _feeTiers['tier1Max']!,
                  tier1Fee: _feeTiers['tier1Fee']!,
                  tier2Max: _feeTiers['tier2Max']!,
                  tier2Fee: _feeTiers['tier2Fee']!,
                  tier3Fee: _feeTiers['tier3Fee']!,
                );

                final feeStr = FeeService.formatFee(fee);
                final priceStr = price
                    .toStringAsFixed(0)
                    .replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                    );

                final scheme = Theme.of(context).colorScheme;

                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 20,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: '$priceStr Ks နဲ့ ရောင်းပြီးရင် ',
                              ),
                              TextSpan(
                                text: 'Platform fee: $feeStr',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    ' ကောက်ခံပါမည်',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            AccessoriesSection(
              box: accBox,
              charger: accCharger,
              cable: accCable,
              earphones: accEarphones,
              receipt: accReceipt,
              onBoxChanged: (v) => setState(() => accBox = v),
              onChargerChanged: (v) => setState(() => accCharger = v),
              onCableChanged: (v) => setState(() => accCable = v),
              onEarphonesChanged: (v) => setState(() => accEarphones = v),
              onReceiptChanged: (v) => setState(() => accReceipt = v),
            ),
            const SizedBox(height: 8),
            DetailsSection(detailController: detailController),
            const SizedBox(height: 15),
            SubmitSection(
              isUploading: _isUploading,
              isImageUploading: _isUploading,
              canSubmit: !_isUploading,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isLoggedIn
          ? Container(
        color: scheme.surface,
        padding:
        const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "အကောင့်မဝင်ရသေးပါ",
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.signup),
              child: const Text("ဝင်ရန် / အကောင့်ဖွင့်ရန်"),
            ),
          ],
        ),
      )
          : null,
    );
  }
}