import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../app_styles.dart';
import '../../../data/services/brand_service.dart';
import '../../../data/services/model_service.dart';
import '../../../data/services/product_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/brand_model_section.dart';
import '../../../shared/widgets/product_image_picker.dart';
import '../../../shared/widgets/specs_section.dart';
import '../../../core/utils/imei_validator.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final BrandService _brandService = BrandService();
  final ModelService _modelService = ModelService();
  final ProductService _productService = ProductService();
  final StorageService _storageService = StorageService();

  late final Stream<List<String>> _brandsStream =
  _brandService.streamActiveBrands();
  late final Stream<List<PhoneModelEntry>> _modelsStream =
  _modelService.streamPhoneModels();

  final TextEditingController priceController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController imeiController = TextEditingController(); // ✅ ADDED
  final TextEditingController detailController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();

  static const String dtAndroidPhone = "android_phone";
  static const String dtAndroidTablet = "android_tablet";
  static const String dtIphone = "iphone";
  static const String dtIpad = "ipad";

  String selectedDeviceType = dtAndroidPhone;
  String selectedCondition = "Brand New";
  int? selectedRam;
  int? selectedStorage;
  String selectedColor = "";
  int? selectedBatteryPercent;
  int? selectedWarrantyDays;

  bool _isUploading = false;
  bool _isImageUploading = false;
  List<XFile> _pickedImages = [];
  XFile? _imeiPhoto;
  static const List<String> conditions = [
    "Brand New",
    "Like New",
    "Used (Good)",
    "Used (Fair)",
  ];

  int? _autoRamFor(String dt, String brand, String model) {
    final b = brand.toLowerCase().trim();
    final m = model.toLowerCase().trim();
    if (dt == dtIphone || b == "apple") {
      if (m.contains("iphone 11")) return 4;
      if (m.contains("iphone 12")) return 4;
      if (m.contains("iphone 13")) return 4;
      if (m.contains("iphone 14")) return 6;
      if (m.contains("iphone 15")) return 6;
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

  String? validateForm() {
    if (_pickedImages.isEmpty) return "ပုံရွေးပေးပါ (Gallery)";
    if (priceController.text.trim().isEmpty) return "ဈေးနှုန်း ထည့်ပါ";
    if (phoneController.text.trim().isEmpty) return "ဖုန်းနံပါတ် ထည့်ပါ";

    // ✅ Only require IMEI if NOT Brand New
    if (selectedCondition != "Brand New") {
      final imei = imeiController.text.trim();

      if (imei.isEmpty) {
        return "IMEI ထည့်ပါ (Used ဖုန်းအတွက်လိုအပ်သည်)";
      }

      if (!ImeiValidator.isValid(imei)) {
        return "IMEI မမှန်ပါ (Invalid IMEI)";
      }

      // 🔥 ADD THIS HERE
      if (_imeiPhoto == null) {
        return "IMEI Live Photo ရိုက်ပါ";
      }
    }

    if (brandController.text.trim().isEmpty) return "Brand ထည့်ပါ (ရိုက်/ရွေး)";
    if (modelController.text.trim().isEmpty) return "Model ထည့်ပါ (ရိုက်/ရွေး)";
    if (selectedRam == null) return "RAM ရွေးပါ";
    if (selectedStorage == null) return "Storage ရွေးပါ";
    if (selectedBatteryPercent == null) return "Battery Health ရွေးပါ";
    if (selectedWarrantyDays == null) return "Warranty ရွေးပါ";

    return null;
  }

  Future<void> uploadProduct() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("အရင်ဆုံး Login ဝင်ပါ")),
      );
      return;
    }

    final error = validateForm();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }


    setState(() => _isUploading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final udata = userDoc.data() ?? {};
      final sellerName = (udata['name'] ?? "အမည်မသိရောင်းသူ").toString();

      setState(() => _isImageUploading = true);
      final imageUrls = await _storageService.uploadProductImages(
        uid: user.uid,
        files: _pickedImages,
      );
      if (imageUrls.isEmpty) {
        throw Exception("No image uploaded");
      }
      final coverImage = imageUrls.first;
      String? imeiPhotoUrl;

      if (selectedCondition != "Brand New" && _imeiPhoto != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('imei_photos')
            .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(File(_imeiPhoto!.path));
        imeiPhotoUrl = await ref.getDownloadURL();
      }


      final autoName = modelController.text.trim();
      final detail = detailController.text.trim();
      final price = priceController.text.trim();
      final phone = phoneController.text.trim();
      final brand = brandController.text.trim();
      final model = modelController.text.trim();

      final imei = selectedCondition == "Brand New"
          ? ""
          : imeiController.text.trim();
      if (selectedCondition != "Brand New") {
        final exists = await _productService.isImeiAlreadyExists(imei);

        if (exists) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ဒီ IMEI နဲ့ ဖုန်းတစ်လုံး ရှိပြီးသားဖြစ်ပါတယ်")),
          );
          return;
        }
      }

      await _productService.createProduct({
        'name': autoName,
        'detail': detail,
        'price': price,
        'phone': phone,
        'imei': imei, // ✅ ADDED
        'imeiPhoto': imeiPhotoUrl ?? "",
        'category': 'ဖုန်း',
        'deviceType': selectedDeviceType,
        'brand': brand,
        'model': model,
        'condition': selectedCondition,
        'image': coverImage,
        'coverImage': coverImage,
        'images': imageUrls,
        'sellerId': user.uid,
        'sellerName': sellerName,
        'specs': {
          'ram': selectedRam,
          'storage': selectedStorage,
          'color': selectedColor.trim(),
          'batteryPercent': selectedBatteryPercent,
          'warrantyDays': selectedWarrantyDays,
          'condition': selectedCondition.trim(),
        },
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _productService.ensureModelExists(brand, model);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ပစ္စည်းတင်ပြီးပါပြီ")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isImageUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    priceController.dispose();
    phoneController.dispose();
    imeiController.dispose(); // ✅ ADDED
    detailController.dispose();
    brandController.dispose();
    modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("ပစ္စည်းအသစ်တင်ရန်", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            BrandModelStatus(
              brandsStream: _brandsStream,
              modelsStream: _modelsStream,
            ),
            ProductImagePicker(
              images: _pickedImages,
              onChanged: (images) => setState(() => _pickedImages = images),
              isUploading: _isImageUploading,
            ),
            _DeviceTypeConditionSection(
              selectedDeviceType: selectedDeviceType,
              selectedCondition: selectedCondition,
              imeiController: imeiController,
              imeiPhoto: _imeiPhoto,
              onImeiPhotoPicked: (photo) {
                setState(() {
                  _imeiPhoto = photo;
                });
              },
              onDeviceTypeChanged: (v) {
                if (v == null) return;
                setState(() {
                  selectedDeviceType = v;
                  modelController.clear();
                });
              },
              onConditionChanged: (v) {
                setState(() {
                  selectedCondition = v ?? "Brand New";
                  if (selectedCondition == "Brand New") {
                    imeiController.clear();
                    _imeiPhoto = null;
                  }
                });
              },
            ),
            SpecsSection(
              selectedRam: selectedRam,
              selectedStorage: selectedStorage,
              selectedColor: selectedColor,
              selectedBatteryPercent: selectedBatteryPercent,
              selectedWarrantyDays: selectedWarrantyDays,
              onRamChanged: (v) => setState(() => selectedRam = v),
              onStorageChanged: (v) => setState(() => selectedStorage = v),
              onColorChanged: (v) => setState(() => selectedColor = (v ?? "")),
              onBatteryChanged: (v) => setState(() => selectedBatteryPercent = v),
              onWarrantyChanged: (v) => setState(() => selectedWarrantyDays = v),
            ),

            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "ဈေးနှုန်း",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "ဆက်သွယ်ရန် ဖုန်းနံပါတ်",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            BrandModelSection(
              brandsStream: _brandsStream,
              modelsStream: _modelsStream,
              brandController: brandController,
              modelController: modelController,
              selectedDeviceType: selectedDeviceType,
              onBrandChanged: () {
                modelController.clear();
                setState(() {});
              },
              onModelChanged: () => setState(() {}),
              onModelInputChanged: () {
                setState(() {});
                _maybeAutoFillRam();
              },
            ),

            const SizedBox(height: 14),
            TextField(
              controller: detailController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "အသေးစိတ် / မှတ်ချက် (Seller အတွက်)",
                hintText: "ဥပမာ: 99% အသစ်, Battery 90%, Box ပါ, Warranty ရှိ/မရှိ ...",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 15),

            _SubmitSection(
              isUploading: _isUploading,
              isImageUploading: _isImageUploading,
              onSubmit: uploadProduct,
              canSubmit: selectedRam != null &&
                  selectedStorage != null &&
                  selectedBatteryPercent != null &&
                  selectedWarrantyDays != null,
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isLoggedIn
          ? Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "အကောင့်မဝင်ရသေးပါ",
                style: TextStyle(color: Colors.white),
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

class _DeviceTypeConditionSection extends StatelessWidget {
  final String selectedDeviceType;
  final String selectedCondition;
  final ValueChanged<String?> onDeviceTypeChanged;
  final ValueChanged<String?> onConditionChanged;
  final TextEditingController imeiController;
  final XFile? imeiPhoto;
  final Function(XFile) onImeiPhotoPicked;

  const _DeviceTypeConditionSection({
    required this.selectedDeviceType,
    required this.selectedCondition,
    required this.onDeviceTypeChanged,
    required this.onConditionChanged,
    required this.imeiController,
    required this.imeiPhoto,
    required this.onImeiPhotoPicked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedDeviceType,
          decoration: const InputDecoration(
            labelText: "Device Type",
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: _AddProductPageState.dtAndroidPhone,
              child: Text("Android Phone"),
            ),
            DropdownMenuItem(
              value: _AddProductPageState.dtAndroidTablet,
              child: Text("Android Tablet"),
            ),
            DropdownMenuItem(
              value: _AddProductPageState.dtIphone,
              child: Text("iPhone"),
            ),
            DropdownMenuItem(
              value: _AddProductPageState.dtIpad,
              child: Text("iPad"),
            ),
          ],
          onChanged: onDeviceTypeChanged,
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: selectedCondition,
          decoration: const InputDecoration(
            labelText: "Condition",
            border: OutlineInputBorder(),
          ),
          items: _AddProductPageState.conditions
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onConditionChanged,
        ),
        const SizedBox(height: 15),

        if (selectedCondition != "Brand New") ...[
          TextField(
            controller: imeiController,
            keyboardType: TextInputType.number,
            maxLength: 15,
            decoration: const InputDecoration(
              labelText: "IMEI (15 digits)",
              prefixIcon: Icon(Icons.confirmation_number),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),

          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: Text(
              imeiPhoto == null
                  ? "IMEI Live Photo ရိုက်ပါ"
                  : "IMEI Photo ပြန်ရိုက်ရန်",
            ),
            onPressed: () async {
              final picker = ImagePicker();
              final photo = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 80,
              );
              if (photo != null) {
                onImeiPhotoPicked(photo);
              }
            },
          ),

          if (imeiPhoto != null) ...[
            const SizedBox(height: 8),
            Image.file(
              File(imeiPhoto!.path),
              height: 120,
            ),
          ],
          const SizedBox(height: 15),
        ],
      ],
    );
  }
}

class _SubmitSection extends StatelessWidget {
  final bool isUploading;
  final bool isImageUploading;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const _SubmitSection({
    required this.isUploading,
    required this.isImageUploading,
    required this.canSubmit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isUploading) return const CircularProgressIndicator();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (isUploading || isImageUploading || !canSubmit) ? null : onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text("တင်မည်", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}