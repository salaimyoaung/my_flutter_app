// order_form_page.dart
// DEPOSIT + ADMIN APPROVE FLOW (FULL CLEAN VERSION)

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../app_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/services/order_service.dart';
import '../../../data/models/product_model.dart';

class OrderFormPage extends StatefulWidget {
  final Product product;
  final String sellerName;

  const OrderFormPage({
    super.key,
    required this.product,
    required this.sellerName,
  });

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _txController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  File? _screenshotFile;

  String? _buyerCity;
  String? _sellerCity;

  int _depositAmount = 0;
  int _qty = 1;
  bool _loading = false;

  final List<String> majorCities = [
    "Yangon",
    "Mandalay",
    "Naypyidaw",
    "Bago",
    "Taungoo",
    "Pyay",
    "Mawlamyine",
    "Pathein",
    "Magway",
    "Myitkyina",
  ];

  @override
  void initState() {
    super.initState();
    _loadSellerCity();
  }

  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _addressController.dispose();
    _txController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerCity() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.product.sellerId)
        .get();

    final city = (doc.data()?['shopCity'] ?? '').toString().trim();

    _sellerCity = city.isEmpty ? null : city;

    _calculateDeposit();
  }

  void _calculateDeposit() {
    if (_buyerCity == null || _sellerCity == null) return;

    if (_buyerCity == _sellerCity) {
      _depositAmount = 10000;
    } else {
      _depositAmount = 20000;
    }

    setState(() {});
  }

  Future<void> _pickScreenshot() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _screenshotFile = File(picked.path));
  }

  Future<String> _uploadScreenshot(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Login required");

    final ref = FirebaseStorage.instance
        .ref()
        .child(
      "deposit_screenshots/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.go(AppRoutes.signup);
      return;
    }

    // 🔒 Validation
    if (_buyerNameController.text.trim().isEmpty ||
        _buyerPhoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      _snack("အချက်အလက်ပြည့်စုံအောင်ဖြည့်ပါ");
      return;
    }

    if (_buyerCity == null || _buyerCity!.isEmpty) {
      _snack("မြို့ရွေးပါ");
      return;
    }

    if (_depositAmount == 0) {
      _snack("Deposit မတွက်ရသေးပါ");
      return;
    }

    if (_txController.text.trim().isEmpty) {
      _snack("Transaction ID ထည့်ပါ");
      return;
    }

    if (_screenshotFile == null) {
      _snack("Screenshot ထည့်ပါ");
      return;
    }

    setState(() => _loading = true);

    try {
      final screenshotUrl = await _uploadScreenshot(_screenshotFile!);

      await OrderService.createOrder(
        productId: widget.product.id,
        productName: widget.product.name,
        productPrice: widget.product.price,
        productImage: widget.product.image,
        sellerId: widget.product.sellerId,
        sellerName: widget.sellerName,
        buyerId: user.uid,
        buyerName: _buyerNameController.text.trim(),
        buyerPhone: _buyerPhoneController.text.trim(),
        buyerAddress: _addressController.text.trim(),
        quantity: _qty,
        depositAmount: _depositAmount,
        depositCity: _buyerCity!, // FIXED
        depositTxId: _txController.text.trim(),
        depositScreenshotUrl: screenshotUrl,

      );

      if (!mounted) return;

      Navigator.pop(context);
      _snack("Order တင်ပြီးပါပြီ (Admin Approval စောင့်ပါ)");

    } catch (e) {
      _snack("Error: $e");
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text("Order + Deposit"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// Buyer Info
            TextField(
              controller: _buyerNameController,
              decoration: const InputDecoration(
                labelText: "Buyer Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _buyerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            /// City Dropdown
            DropdownButtonFormField<String>(
              value: _buyerCity,
              decoration: const InputDecoration(
                labelText: "Your City",
                border: OutlineInputBorder(),
              ),
              items: majorCities
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _buyerCity = v;
                });
                _calculateDeposit();
              },
            ),

            const SizedBox(height: 16),



      TextFormField(
      controller: _addressController,
      maxLines: 3,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.streetAddress,
      decoration: InputDecoration(
        labelText: "Buyer Address",
        hintText: "Street, Ward, Township, Landmark",
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.location_on_outlined),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (value) {
        final v = value?.trim() ?? "";

        if (v.isEmpty) {
          return "Buyer address ထည့်ပါ";
        }

        if (v.length < 10) {
          return "Address အပြည့်အစုံ ထည့်ပါ";
        }

        return null;
      },
    ),

            if (_depositAmount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "Deposit Amount: $_depositAmount MMK",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "ပစ္စည်းရရှိပြီး Received နှိပ်ပါက Admin မှ Deposit ပြန်လွှဲပေးပါမည်။",
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),

            const SizedBox(height: 20),

            const Text("Deposit Bank Accounts"),
            const SizedBox(height: 8),
            const Text("KBZPay - 09xxxxxxx"),
            const Text("WavePay - 09xxxxxxx"),
            const Text("AYA Bank - xxxxxxxx"),

            const SizedBox(height: 20),

            TextField(
              controller: _txController,
              decoration: const InputDecoration(
                labelText: "Transaction ID",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _pickScreenshot,
              icon: const Icon(Icons.image),
              label: const Text("Upload Screenshot"),
            ),

            const SizedBox(height: 30),

            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text("Submit Order"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}