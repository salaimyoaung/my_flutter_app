import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'imei_scanner_page.dart';

class ImeiSection extends StatefulWidget {
  final TextEditingController imeiController;
  final ValueChanged<XFile?> onImeiPhotoPicked;
  final XFile? initialPhoto; // ✅ Added to maintain state on rebuild

  const ImeiSection({
    super.key,
    required this.imeiController,
    required this.onImeiPhotoPicked,
    this.initialPhoto,
  });

  @override
  State<ImeiSection> createState() => _ImeiSectionState();
}

class _ImeiSectionState extends State<ImeiSection> {
  XFile? _imeiPhoto;
  bool _hasImei = false; // true when IMEI field has content

  static const _imgQuality = 85;

  @override
  void initState() {
    super.initState();
    _imeiPhoto = widget.initialPhoto; // ✅ Populate from initialPhoto
    _hasImei = widget.imeiController.text.trim().isNotEmpty;
    widget.imeiController.addListener(_onImeiChanged);
  }

  void _onImeiChanged() {
    final hasNow = widget.imeiController.text.trim().isNotEmpty;
    if (hasNow != _hasImei) {
      setState(() => _hasImei = hasNow);
      // Clear photo if IMEI cleared
      if (!hasNow && _imeiPhoto != null) {
        _imeiPhoto = null;
        widget.onImeiPhotoPicked(null);
      }
    }
  }

  @override
  void dispose() {
    widget.imeiController.removeListener(_onImeiChanged);
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: _imgQuality,
    );
    if (photo == null || !mounted) return;
    setState(() {
      _imeiPhoto = photo;
      widget.onImeiPhotoPicked(photo);
    });
  }

  void _removePhoto() {
    setState(() {
      _imeiPhoto = null;
      widget.onImeiPhotoPicked(null);
    });
  }

  Future<void> _openScannerFor(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ImeiScannerPage()),
    );
    if (scanned != null && scanned.isNotEmpty) {
      controller.text = scanned;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: scanned.length),
      );
    }
  }

  // ── Photo preview / camera tile ──────────────────────────────────────────
  Widget _photoTile(XFile? photo, VoidCallback onCamera, VoidCallback onRemove) {
    final scheme = Theme.of(context).colorScheme;
    if (photo == null) {
      return GestureDetector(
        onTap: onCamera,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
            color: scheme.surfaceContainerLowest,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 28, color: scheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                'ဓာတ်ပုံရိုက်မည်',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(photo.path),
            height: 90,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        // Retake button
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: onCamera,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ပြန်ရိုက်',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Scan button ───────────────────────────────────────────────────────────
  Widget _scanBtn(TextEditingController ctrl) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: primary),
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => _openScannerFor(context, ctrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Privacy notice ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'IMEI နံပါတ်ကို users များ မမြင်ရပါ။ Admin verification နှင့် fraud prevention အတွက်သာ သိမ်းဆည်းပါသည်။ IMEI တင်ပေးမှသာ adminက စစ်ပေးပြီး C.E.E.R activate ဖြစ်မဖြစ်နဲ့ device verify ဖြစ်မဖြစ်ကို  ဝယ်သူတွေဆီ ပြပေးလို့ ရမှာ ဖြစ်ပါသည်။ IMEI နံပါတ်ကို *#06# ကို ခေါ်ဆိုခြင်းကနေ ဖြစ်စေ settingကနေဖြစ်စေ ဘူးခွံကနေဖြစ်စေ ရရှိနိုင်ပါသည်',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        // ── IMEI field (optional) ───────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: widget.imeiController,
                keyboardType: TextInputType.number,
                maxLength: 15,
                decoration: const InputDecoration(
                  labelText: 'IMEI (optional)',
                  hintText: '15-digit IMEI number',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            _scanBtn(widget.imeiController),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
          child: Text(
            'IMEI ထည့်ပါက admin verification စစ်ပေးပြီး buyer ယုံကြည်မှု မြင့်သည်',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),

        // ── IMEI Live Photo — only shown when IMEI entered ──────────────────
        if (_hasImei) ...[
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined, size: 16),
              const SizedBox(width: 6),
              const Text('IMEI Live Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              const Text('*',
                  style: TextStyle(
                      color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          _photoTile(_imeiPhoto, () => _takePhoto(), () => _removePhoto()),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
            child: Text(
              'ဖုန်း Settings → About Phone → IMEI ပြထားသော screen ကို live ရိုက်ပါ',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],

        const SizedBox(height: 0),
      ],
    );
  }
}
