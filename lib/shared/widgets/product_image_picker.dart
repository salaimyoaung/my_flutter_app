import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProductImagePicker extends StatefulWidget {
  final List<XFile> images;
  final ValueChanged<List<XFile>> onChanged;
  final bool isUploading;
  final int maxImages;

  const ProductImagePicker({
    super.key,
    required this.images,
    required this.onChanged,
    required this.isUploading,
    this.maxImages = 4,
  });

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      if (files.isEmpty) return;

      var selected = files;
      if (selected.length > widget.maxImages) {
        selected = selected.sublist(0, widget.maxImages);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ပုံ ${widget.maxImages} ပုံအထိသာရွေးနိုင်ပါတယ်"),
          ),
        );
      }

      widget.onChanged(selected);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gallery error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.images.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.images.first.path),
                    fit: BoxFit.cover,
                  ),
                )
              : const Center(child: Icon(Icons.image, size: 48)),
        ),
        const SizedBox(height: 12),
        if (widget.images.isNotEmpty) ...[
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final x = widget.images[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(x.path),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.isUploading ? null : _pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  widget.images.isEmpty
                      ? "Choose from Gallery"
                      : "Change Images (${widget.images.length}/${widget.maxImages})",
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (widget.isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}
