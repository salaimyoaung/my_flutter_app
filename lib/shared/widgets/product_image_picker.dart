import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class ProductImagePicker extends StatefulWidget {
  final List<XFile> images;
  final ValueChanged<List<XFile>> onChanged;
  final bool isUploading;
  final int maxImages;
  
  // ✅ Assets tracking for gallery selection memory
  final List<AssetEntity> selectedAssets;
  final ValueChanged<List<AssetEntity>> onAssetsChanged;

  const ProductImagePicker({
    super.key,
    required this.images,
    required this.onChanged,
    required this.isUploading,
    this.maxImages = 8,
    required this.selectedAssets,
    required this.onAssetsChanged,
  });

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  final ImagePicker _picker = ImagePicker();

  static const int _imageQuality  = 85;
  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB

  // ─── Gallery picker (wechat_assets_picker) ────────────────────────────────
  Future<void> _pickFromGallery() async {
    // Permission request
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery ခွင့်ပြုချက် မရပါ')),
      );
      return;
    }

    if (!mounted) return;

    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: widget.maxImages,
        selectedAssets: widget.selectedAssets,   // ✅ Use assets from parent
        requestType: RequestType.image,
        gridCount: 3,
        pageSize: 60,
        themeColor: Theme.of(context).colorScheme.primary,
      ),
    );

    if (result == null) return; // user cancelled

    // ── Convert AssetEntity → XFile ──────────────────────────────────────────
    final xFiles = <XFile>[];
    final validAssets = <AssetEntity>[];
    final skipped = <String>[];

    for (final asset in result) {
      final file = await asset.file;
      if (file == null) continue;

      final bytes = await file.length();
      if (bytes > _maxFileSizeBytes) {
        skipped.add(asset.title ?? 'Unknown');
        continue;
      }

      xFiles.add(XFile(file.path));
      validAssets.add(asset);
    }

    if (skipped.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${skipped.length} ပုံ ဖိုင်အရွယ်အစားကြီးလွန်းသောကြောင့် ဖြုတ်လိုက်သည် (max 25MB)',
        ),
      ));
    }

    // ✅ Notify parent about new assets and files
    widget.onAssetsChanged(validAssets);
    widget.onChanged(xFiles);
  }

  // ─── Camera picker (unchanged) ────────────────────────────────────────────
  Future<void> _pickFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _imageQuality,
      );
      if (file == null) return;

      if (widget.images.length >= widget.maxImages) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ပုံ ${widget.maxImages} ပုံအထိသာရွေးနိုင်ပါတယ်'),
          ),
        );
        return;
      }

      final bytes = await File(file.path).length();
      if (bytes > _maxFileSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ဖိုင်အရွယ်အစားကြီးလွန်းသည် (max 25MB)')),
        );
        return;
      }

      final merged = {
        ...widget.images,
        file,
      }.fold<Map<String, XFile>>({}, (m, x) => m..[x.path] = x).values.toList();

      // ✅ Camera ကနေ ထည့်တဲ့ ပုံ AssetEntity မရှိသောကြောင့် parent asset list ကို clear
      //    (picker ဖွင့်ရင် camera photo pre-select မပြ — acceptable limitation)
      widget.onAssetsChanged([]);
      widget.onChanged(merged);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  void _removeImage(int index) {
    final updated = List<XFile>.from(widget.images)..removeAt(index);
    // ✅ AssetEntity list ကိုလည်း sync လုပ်
    if (index < widget.selectedAssets.length) {
      final updatedAssets = List<AssetEntity>.from(widget.selectedAssets)..removeAt(index);
      widget.onAssetsChanged(updatedAssets);
    }
    widget.onChanged(updated);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final hasImages = widget.images.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main Preview ──────────────────────────────────────────────────────
        Container(
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: hasImages
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.images.first.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                )
              : const Center(child: Icon(Icons.image, size: 48)),
        ),

        const SizedBox(height: 12),

        // ── Thumbnails ────────────────────────────────────────────────────────
        if (hasImages) ...[
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final x       = widget.images[i];
                final isCover = i == 0;

                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(x.path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    if (isCover)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: scheme.primary.withValues(alpha: 0.75),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Cover',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: widget.isUploading ? null : () => _removeImage(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.error,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: scheme.onError,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Action Buttons ────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.isUploading ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  !hasImages
                      ? 'Gallery မှ ရွေးမည်'
                      : 'Images ပြောင်းမည် (${widget.images.length}/${widget.maxImages})',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.isUploading ? null : _pickFromCamera,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
            ),
            if (widget.isUploading) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),

        const SizedBox(height: 15),
      ],
    );
  }
}
