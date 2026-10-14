import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

/// Full-screen image viewer — single or multi-image with swipe + zoom + save.
///
/// Single image:
///   FullScreenImagePage.show(context, url);
///
/// Multi-image (e.g. product gallery):
///   FullScreenImagePage.showGallery(context, urls, initialIndex: 0);
class FullScreenImagePage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImagePage._({
    required this.images,
    required this.initialIndex,
  });

  /// Show a single image full-screen.
  static void show(BuildContext context, String url) {
    if (url.isEmpty) return;
    _push(context, [url], 0);
  }

  /// Show a gallery of images full-screen, starting at [initialIndex].
  static void showGallery(
    BuildContext context,
    List<String> urls, {
    int initialIndex = 0,
  }) {
    final filtered = urls.where((u) => u.isNotEmpty).toList();
    if (filtered.isEmpty) return;
    _push(context, filtered, initialIndex.clamp(0, filtered.length - 1));
  }

  static void _push(BuildContext context, List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            FullScreenImagePage._(images: images, initialIndex: index),
      ),
    );
  }

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late final PageController _pageCtrl;
  late int _currentIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String get _currentUrl => widget.images[_currentIndex];

  Future<void> _saveImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final response = await http.get(Uri.parse(_currentUrl));
      if (response.statusCode != 200) throw Exception('Download failed');

      final Uint8List bytes = response.bodyBytes;
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'img_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      final success = result['isSuccess'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Gallery သို့ သိမ်းပြီး ✅' : 'သိမ်းမရပါ ❌'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // e.g. "2 / 4"
        title: total > 1
            ? Text(
                '${_currentIndex + 1} / $total',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              )
            : null,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Gallery သို့ သိမ်း',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            onPressed: _saving ? null : _saveImage,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: total,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white54)),
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
